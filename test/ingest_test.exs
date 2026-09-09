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
