defmodule Ex4pm.Stream.IngestTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.OnlineMiner
  alias Ex4pm.Evidence.Store
  alias Ex4pm.Stream.Ingest

  setup do
    {:ok, store} = start_supervised({Store, [name: :test_ingest_store]})
    {:ok, miner} = start_supervised({OnlineMiner, [name: :test_ingest_miner]})
    %{store: store, miner: miner}
  end

  test "ingests valid OCEL 2.0 batch envelope idempotently", %{store: store, miner: miner} do
    envelope = %{
      "schema" => "chatgpt-cloud-ocel/1",
      "producer" => %{
        "agent_id" => "chatgpt-cloud-482",
        "run_id" => "run-8e34",
        "runtime" => "beam-27"
      },
      "sequence" => 1,
      "previous_digest" => nil,
      "objects" => %{
        "repo-1" => %{"id" => "repo-1", "type" => "Repository", "name" => "ash_r2rml"},
        "commit-1" => %{"id" => "commit-1", "type" => "Commit", "sha" => "7e5718cd"}
      },
      "events" => [
        %{
          "id" => "e-101",
          "activity" => "github.fetch_file",
          "timestamp" => "2026-08-21T18:14:00Z",
          "relationships" => [%{"objectId" => "repo-1", "qualifier" => "source"}],
          "agent_id" => "chatgpt-cloud-482",
          "run_id" => "run-8e34"
        },
        %{
          "id" => "e-102",
          "activity" => "github.commit",
          "timestamp" => "2026-08-21T18:14:05Z",
          "relationships" => [%{"objectId" => "commit-1", "qualifier" => "created"}],
          "agent_id" => "chatgpt-cloud-482",
          "run_id" => "run-8e34"
        }
      ]
    }

    assert {:ok, result} = Ingest.ingest_envelope(envelope, store: store, miner: miner)
    assert result.status == :ingested
    assert result.event_count == 2
    assert result.object_count == 2
    assert result.agent_id == "chatgpt-cloud-482"

    # Verify miner received events
    summary = OnlineMiner.get_summary(miner)
    assert summary.total_events == 2

    # Verify store recorded receipt
    all_receipts = Store.all(store)
    assert length(all_receipts) >= 2
  end

  test "deduplicates a real duplicate re-ingestion (same logical event, retried)", %{
    store: store,
    miner: miner
  } do
    envelope = %{
      "schema" => "chatgpt-cloud-ocel/1",
      "producer" => %{
        "agent_id" => "chatgpt-cloud-482",
        "run_id" => "run-dedupe-1",
        "runtime" => "beam-27"
      },
      "sequence" => 1,
      "previous_digest" => nil,
      "objects" => %{
        "repo-1" => %{"id" => "repo-1", "type" => "Repository", "name" => "ash_r2rml"}
      },
      "events" => [
        %{
          "id" => "e-201",
          "activity" => "github.fetch_file",
          "timestamp" => "2026-09-09T18:14:00Z",
          "relationships" => [%{"objectId" => "repo-1", "qualifier" => "source"}],
          "agent_id" => "chatgpt-cloud-482",
          "run_id" => "run-dedupe-1"
        }
      ]
    }

    # First ingest: real, committed, forwarded to the miner.
    assert {:ok, first} = Ingest.ingest_envelope(envelope, store: store, miner: miner)
    assert first.status == :ingested

    summary_after_first = OnlineMiner.get_summary(miner)
    assert summary_after_first.total_events == 1

    receipts_after_first = Store.all(store)
    outcome_count_after_first = Enum.count(receipts_after_first, &(&1.phase == :outcome))

    # Second call: identical logical event content (same activity/object/timestamp),
    # resubmitted with a *different* sequence number -- simulating an Ash bulk-action
    # retry or a nested Ash.Actions.Helpers.notify/3 firing the same notification
    # twice. A real fix must collapse this, not commit a second OCEL event/receipt.
    retried_envelope = put_in(envelope["sequence"], 2)

    assert {:ok, second} = Ingest.ingest_envelope(retried_envelope, store: store, miner: miner)
    assert second.status == :duplicate_ignored
    assert second.subject_hash == first.subject_hash

    # No second event reached the miner.
    summary_after_second = OnlineMiner.get_summary(miner)
    assert summary_after_second.total_events == 1

    # No second outcome receipt was committed.
    receipts_after_second = Store.all(store)
    outcome_count_after_second = Enum.count(receipts_after_second, &(&1.phase == :outcome))
    assert outcome_count_after_second == outcome_count_after_first
  end

  test "does NOT deduplicate a genuinely distinct occurrence of the same activity", %{
    store: store,
    miner: miner
  } do
    base_envelope = %{
      "schema" => "chatgpt-cloud-ocel/1",
      "producer" => %{
        "agent_id" => "chatgpt-cloud-482",
        "run_id" => "run-distinct-1",
        "runtime" => "beam-27"
      },
      "sequence" => 1,
      "previous_digest" => nil,
      "objects" => %{
        "repo-1" => %{"id" => "repo-1", "type" => "Repository", "name" => "ash_r2rml"}
      },
      "events" => [
        %{
          "id" => "e-301",
          "activity" => "github.fetch_file",
          "timestamp" => "2026-09-09T18:14:00Z",
          "relationships" => [%{"objectId" => "repo-1", "qualifier" => "source"}],
          "agent_id" => "chatgpt-cloud-482",
          "run_id" => "run-distinct-1"
        }
      ]
    }

    assert {:ok, first} = Ingest.ingest_envelope(base_envelope, store: store, miner: miner)
    assert first.status == :ingested

    # A real second occurrence of the same activity at a later real timestamp is a
    # distinct logical event and must NOT be collapsed by the dedup check.
    later_envelope =
      base_envelope
      |> put_in(["sequence"], 2)
      |> put_in(["events", Access.at(0), "id"], "e-302")
      |> put_in(["events", Access.at(0), "timestamp"], "2026-09-09T19:00:00Z")

    assert {:ok, second} = Ingest.ingest_envelope(later_envelope, store: store, miner: miner)
    assert second.status == :ingested
    refute second.subject_hash == first.subject_hash

    summary = OnlineMiner.get_summary(miner)
    assert summary.total_events == 2
  end

  test "refuses invalid envelope schema or sequence" do
    invalid_envelope = %{
      "schema" => "unknown-schema/99",
      "producer" => %{"agent_id" => "agent-1"},
      "sequence" => -5,
      "events" => []
    }

    assert {:error, refusal} = Ingest.ingest_envelope(invalid_envelope)
    assert refusal.code == :invalid_sequence
  end
end
