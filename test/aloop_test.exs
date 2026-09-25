defmodule Ex4pm.AloopTest do
  use ExUnit.Case, async: true

  alias Ex4pm.{Aloop, Test.AloopFixtures}

  describe "vocabulary" do
    test "declares the ALOOP contract vocabularies" do
      assert Aloop.event_classes() == ~w(
        episode.start observe gap.detect candidate.construct candidate.admit
        plan.select workorder.issue provider.select worker.claim execution.start
        tool.admit actuate checkpoint execution.crash receipt.persist verify
        falsifier.run benchmark.run failure.detect reconcile replan
        provider.replace commit merge reobserve goal.satisfied goal.blocked
        episode.terminal
      )

      for t <- ~w(Episode Objective Requirement WorkOrder Authority Repository Subject
                  Provider Worker WorkerRun Plan Capability Candidate Consequence Evidence
                  Receipt Failure Benchmark Release) do
        assert t in Aloop.object_types()
      end

      assert "originAuthority" in Aloop.qualifiers()
      assert MapSet.size(Aloop.model_edges()) > 0
    end
  end

  describe "ingest" do
    test "normalizes the fixture corpus through the canonical OCEL IR" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corpus())
      assert length(log.events) == 91
      assert map_size(log.objects) == 28
    end

    test "refuses a non-log observation" do
      assert {:error, %Ex4pm.Refusal{}} = Aloop.ingest(%{"nope" => 1})
    end
  end

  describe "recurrence / loop depth" do
    test "clean episode recurs to depth 2" do
      {:ok, log} = Aloop.ingest(AloopFixtures.clean_episode_log())
      assert Aloop.recurrence?(log)
      assert Aloop.loop_depths(log) == %{"ep-1" => 2}
    end

    test "single-iteration episodes do not recur" do
      {:ok, log} = Aloop.ingest(AloopFixtures.human_edge_episode_log())
      refute Aloop.recurrence?(log)
      assert Aloop.loop_depths(log) == %{"ep-2" => 1}
    end

    test "corpus recurrence is carried by ep-1 only" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corpus())
      assert Aloop.recurrence?(log)
      assert Aloop.loop_depths(log) == %{"ep-1" => 2, "ep-2" => 1, "ep-3" => 1, "ep-4" => 1}
    end
  end

  describe "human causal edges" do
    test "planted human originAuthority yields the human -> next-action edge" do
      {:ok, log} = Aloop.ingest(AloopFixtures.human_edge_episode_log())

      assert [%{"activity" => "candidate.construct", "next_activity" => "candidate.admit",
                "event_id" => "e2-03"}] = Aloop.human_causal_edges(log)

      assert Aloop.human_causal_edge_present?(log)
    end

    test "autonomous-only episodes have no human causal edge" do
      {:ok, log} = Aloop.ingest(AloopFixtures.clean_episode_log())
      refute Aloop.human_causal_edge_present?(log)
    end
  end

  describe "provider replacement / substitution equivalence" do
    test "crash -> replace -> re-execution is substitution-equivalent" do
      {:ok, log} = Aloop.ingest(AloopFixtures.provider_substitution_episode_log())

      assert [%{"from_provider" => "p-flash", "to_provider" => "p-zcode",
                "substitution_equivalent" => true}] = Aloop.provider_replacements(log)

      assert Aloop.provider_replacement_occurred?(log)
    end

    test "episodes without replacement report none" do
      {:ok, log} = Aloop.ingest(AloopFixtures.clean_episode_log())
      refute Aloop.provider_replacement_occurred?(log)
    end
  end

  describe "DO/receipt coverage (orphan consequences)" do
    test "clean episode: every actuate is receipted" do
      {:ok, log} = Aloop.ingest(AloopFixtures.clean_episode_log())
      assert Aloop.every_do_receipted?(log)
      assert Aloop.orphan_dos(log) == []
    end

    test "corpus carries exactly the planted ep-4 orphan DO" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corpus())
      refute Aloop.every_do_receipted?(log)

      assert [%{"episode" => "ep-4", "event_id" => "e4-11", "consequence" => "c-4a"}] =
               Aloop.orphan_dos(log)
    end
  end

  describe "receipt consumption" do
    test "clean corpus: every receipt feeds an observation or closes its episode" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corpus())
      assert Aloop.every_receipt_consumed?(log)
    end
  end

  describe "dfg / variants / precision" do
    test "dfg edges never cross episode boundaries and are counted" do
      {:ok, log} = Aloop.ingest(AloopFixtures.clean_episode_log())
      dfg = Aloop.dfg(log)

      assert %{"count" => 2} = Enum.find(dfg, &(&1["from"] == "actuate" and &1["to"] == "checkpoint"))
      assert Enum.find(dfg, &(&1["from"] == "episode.start" and &1["to"] == "observe"))
      # no cross-episode edge can exist; every edge is within ep-1's vocabulary
      assert Enum.all?(dfg, &(&1["count"] >= 1))
    end

    test "four episodes give four distinct variants with stable ids" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corpus())
      variants = Aloop.variants(log)

      assert length(variants) == 4
      assert Enum.uniq(Enum.map(variants, & &1["id"])) |> length() == 4
      assert Enum.all?(variants, &(&1["count"] == 1))
      assert Enum.sum(Enum.map(variants, & &1["count"])) == 4
    end

    test "variant ids are deterministic across regeneration" do
      {:ok, log1} = Aloop.ingest(AloopFixtures.corpus())
      {:ok, log2} = Aloop.ingest(AloopFixtures.corpus())
      assert Aloop.variants(log1) == Aloop.variants(log2)
    end

    test "clean log has precision 1.0 against the ALOOP model" do
      {:ok, log} = Aloop.ingest(AloopFixtures.clean_episode_log())
      assert Aloop.precision(log) == 1.0
    end

    test "empty-edge log has nil precision" do
      {:ok, log} = Aloop.ingest(%{"events" => [], "objects" => []})
      assert Aloop.precision(log) == nil
    end
  end

  describe "conformance" do
    test "clean episode is conformant with zero divergences" do
      {:ok, log} = Aloop.ingest(AloopFixtures.clean_episode_log())
      assert Aloop.conformant?(log)
      assert Aloop.divergences(log) == []
    end

    test "corpus diverges exactly in the planted ep-4 orphan DO" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corpus())
      refute Aloop.conformant?(log)

      assert [%{"type" => "unreceipted_do", "episode" => "ep-4"}] = Aloop.divergences(log)
    end
  end

  describe "repair/replan chains" do
    test "crash -> failure.detect -> provider.replace is one chain" do
      {:ok, log} = Aloop.ingest(AloopFixtures.provider_substitution_episode_log())

      assert [%{"crash_event_id" => "e3-10", "recovery" => "provider.replace",
                "recovery_event_id" => "e3-12"}] = Aloop.repair_replan_chains(log)
    end

    test "episodes without crashes have no repair chains" do
      {:ok, log} = Aloop.ingest(AloopFixtures.clean_episode_log())
      assert Aloop.repair_replan_chains(log) == []
    end
  end

  describe "analysis receipt" do
    test "full corpus receipt answers every mission question machine-readably" do
      receipt = Aloop.analysis_receipt(AloopFixtures.corpus())

      assert receipt["schema"] == "ex4pm.aloop.analysis_receipt/v1"
      assert receipt["standing"] == "ALIVE"
      assert receipt["source"]["corpus_status"] == "RECONSTRUCTED"

      answers = receipt["answers"]
      assert answers["recurrence_occurred"] == true
      assert answers["human_causal_edge_present"] == true
      assert answers["provider_replacement_occurred"] == true
      assert answers["provider_replacements"] |> hd() |> Map.get("substitution_equivalent") == true
      assert answers["every_do_followed_by_receipt"] == false
      assert answers["every_receipt_fed_later_observation"] == true
      assert answers["conformant_to_aloop_model"] == false
      assert is_binary(answers["variants"] |> hd() |> Map.get("id"))
      assert Jason.encode!(receipt)
    end

    test "receipt is deterministic: same log, byte-identical JSON" do
      a = Aloop.analysis_receipt(AloopFixtures.corpus()) |> Jason.encode!()
      b = Aloop.analysis_receipt(AloopFixtures.corpus()) |> Jason.encode!()
      assert a == b
    end

    test "refused log yields a typed REFUSED receipt" do
      receipt = Aloop.analysis_receipt(%{"nothing" => "here"})
      assert receipt["standing"] == "REFUSED"
      assert receipt["refusal"]["code"] == :missing_events
    end
  end

  # -- Anti-vacuity falsifier court: each corruption must be flagged by the
  #    analysis it is the falsifier for. A check that passes its own corruption
  #    carries no bits.
  describe "falsifier court (corrupted logs are flagged)" do
    test ":orphan_do_removed_receipt is flagged by DO/receipt coverage" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corrupted(AloopFixtures.corpus(), :orphan_do_removed_receipt))

      refute Aloop.every_do_receipted?(log)
      assert %{"episode" => "ep-1", "event_id" => "e1-26"} = Enum.find(Aloop.orphan_dos(log), &(&1["episode"] == "ep-1"))
    end

    test ":human_edge_relabeled is flagged by human-causal-edge analysis" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corrupted(AloopFixtures.corpus(), :human_edge_relabeled))

      refute Aloop.human_causal_edge_present?(log)
      assert Aloop.human_causal_edges(log) == []
    end

    test ":provider_replace_removed is flagged by provider-replacement analysis" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corrupted(AloopFixtures.corpus(), :provider_replace_removed))

      refute Aloop.provider_replacement_occurred?(log)
      assert Aloop.provider_replacements(log) == []
    end

    test ":off_vocabulary_activity is flagged by conformance and drops precision" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corrupted(AloopFixtures.corpus(), :off_vocabulary_activity))

      types = Aloop.divergences(log) |> Enum.map(& &1["type"])
      assert "off_vocabulary_activity" in types
      assert Aloop.precision(log) < 1.0
    end

    test ":unconsumed_receipt is flagged by receipt-consumption analysis" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corrupted(AloopFixtures.corpus(), :unconsumed_receipt))

      refute Aloop.every_receipt_consumed?(log)
      assert %{"event_id" => "e1-13"} = Enum.find(Aloop.unconsumed_receipts(log), &(&1["event_id"] == "e1-13"))
    end

    test ":post_terminal_activity is flagged by conformance" do
      {:ok, log} = Aloop.ingest(AloopFixtures.corrupted(AloopFixtures.corpus(), :post_terminal_activity))

      types = Aloop.divergences(log) |> Enum.map(& &1["type"])
      assert "post_terminal_activity" in types
    end

    test "every declared corruption flips its designated signal (no vacuous corruptions)" do
      base = Aloop.analysis_receipt(AloopFixtures.corpus())

      for corruption <- AloopFixtures.corruptions() do
        receipt = Aloop.analysis_receipt(AloopFixtures.corrupted(AloopFixtures.corpus(), corruption))
        assert receipt != base, "corruption #{inspect(corruption)} changed nothing"

        flagged =
          receipt["answers"]["divergences"] != base["answers"]["divergences"] or
            receipt["answers"]["every_do_followed_by_receipt"] !=
              base["answers"]["every_do_followed_by_receipt"] or
            receipt["answers"]["human_causal_edge_present"] !=
              base["answers"]["human_causal_edge_present"] or
            receipt["answers"]["provider_replacement_occurred"] !=
              base["answers"]["provider_replacement_occurred"] or
            receipt["answers"]["every_receipt_fed_later_observation"] !=
              base["answers"]["every_receipt_fed_later_observation"]

        assert flagged, "corruption #{inspect(corruption)} was not flagged by any analysis"
      end
    end
  end

  describe "fixture corpus integrity" do
    test "fixture corpus is marked RECONSTRUCTED and seeded" do
      assert AloopFixtures.seed() =~ "lane-9"
      corpus = AloopFixtures.corpus()
      assert corpus["producer"]["note"] =~ "RECONSTRUCTED"
    end

    test "corpus regeneration is byte-identical (seed discipline)" do
      a = AloopFixtures.corpus() |> Jason.encode!()
      b = AloopFixtures.corpus() |> Jason.encode!()
      assert a == b
    end
  end
end
