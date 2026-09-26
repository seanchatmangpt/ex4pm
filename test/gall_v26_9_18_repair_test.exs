defmodule Ex4pm.GallRepairTest do
  @moduledoc """
  Falsifiers for the PR #47 court findings on GALL-016..020 (v26.9.26
  repair). Each describe block names the defect it kills. Chicago style:
  real modules, real data, state-based assertions only.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.Gall.{Compliance, Compute, Corpus, Discovery, Ocpq, Portable, Powl}

  @sha "5abf57f91e85628a605a1dacace2a50e43fabb8b"

  defp attrs do
    [
      repository: "seanchatmangpt/ex4pm",
      producer_sha: @sha,
      corpus_digest: Corpus.manifest_digest()
    ]
  end

  describe "GALL-016 WF-net ingress follows Petri-net semantics" do
    test "every control-flow corpus fixture agrees through both ingress paths (AC1/AC4)" do
      for id <- ["sequence", "parallel", "choice", "loop"] do
        fixture = Corpus.fixture!(id)
        assert {:ok, semantic} = Powl.from_semantic(fixture.semantic), id
        assert {:ok, wfnet} = Powl.from_wfnet(fixture.wfnet), id
        assert semantic.ingress == :semantic
        assert wfnet.ingress == :wfnet
        assert Powl.equivalent?(semantic, wfnet), "#{id} ingress paths disagree"
      end
    end

    test "an XOR split place is a choice, never concurrency" do
      choice = Corpus.fixture!("choice")
      parallel = Corpus.fixture!("parallel")
      {:ok, wf_choice} = Powl.from_wfnet(choice.wfnet)
      {:ok, wf_parallel} = Powl.from_wfnet(parallel.wfnet)
      {:ok, sem_choice} = Powl.from_semantic(choice.semantic)
      {:ok, sem_parallel} = Powl.from_semantic(parallel.semantic)

      assert wf_choice.model.type == :choice
      assert wf_parallel.model.type == :partial_order
      refute wf_choice.model == wf_parallel.model
      refute Powl.equivalent?(sem_parallel, wf_choice)
      refute Powl.equivalent?(sem_choice, wf_parallel)
      assert Powl.equivalent?(sem_choice, wf_choice)
    end

    test "loop body and redo roles are not interchangeable" do
      {:ok, wf_loop} = Powl.from_wfnet(Corpus.fixture!("loop").wfnet)
      {:ok, swapped} = Powl.from_semantic(%{type: :loop, body: "b", redo: "a"})

      assert wf_loop.model == %{
               type: :loop,
               body: %{type: :task, id: "a"},
               redo: %{type: :task, id: "b"}
             }

      refute Powl.equivalent?(wf_loop, swapped)
    end

    test "nested blocks reduce: concurrency of a task with a choice" do
      net = %{
        transitions: ["split", "a", "b", "c", "join"],
        silent: ["split", "join"],
        flow: [
          {"i", "split"},
          {"split", "p1"},
          {"split", "p2"},
          {"p1", "a"},
          {"a", "q1"},
          {"p2", "b"},
          {"p2", "c"},
          {"b", "q2"},
          {"c", "q2"},
          {"q1", "join"},
          {"q2", "join"},
          {"join", "o"}
        ]
      }

      {:ok, wfnet} = Powl.from_wfnet(net)

      {:ok, semantic} =
        Powl.from_semantic(%{
          type: :partial_order,
          children: ["a", %{type: :choice, children: ["c", "b"]}],
          order: []
        })

      assert Powl.equivalent?(semantic, wfnet)

      {:ok, flat} =
        Powl.from_semantic(%{type: :partial_order, children: ["a", "b", "c"], order: []})

      refute Powl.equivalent?(flat, wfnet)
    end

    test "a sequence inside a loop body and a choice of sequences keep their order relations" do
      loop_net = %{
        transitions: ["enter", "a1", "a2", "r", "exit"],
        silent: ["enter", "exit"],
        flow: [
          {"i", "enter"},
          {"enter", "p"},
          {"p", "a1"},
          {"a1", "m"},
          {"m", "a2"},
          {"a2", "q"},
          {"q", "r"},
          {"r", "p"},
          {"q", "exit"},
          {"exit", "o"}
        ]
      }

      {:ok, wfnet} = Powl.from_wfnet(loop_net)

      {:ok, semantic} =
        Powl.from_semantic(%{
          type: :loop,
          body: %{type: :sequence, children: ["a1", "a2"]},
          redo: "r"
        })

      assert Powl.equivalent?(semantic, wfnet)
      assert Powl.semantic_properties(wfnet).relations == [{"a1", "a2"}]

      {:ok, choice_of_seq} =
        Powl.from_semantic(%{
          type: :sequence,
          children: [%{type: :choice, children: ["a", "b"]}, "c"]
        })

      assert Powl.semantic_properties(choice_of_seq).relations == [{"a", "c"}, {"b", "c"}]
    end

    test "a net that is not block-structured is refused, not re-read as a partial order" do
      # i -> a -> p ; i -> b -> p ; p -> c -> o ; a -> x -> c (a and b are
      # alternatives but a also feeds c directly): no reduction rule applies.
      net = %{
        transitions: ["a", "b", "c"],
        flow: [
          {"i", "a"},
          {"i", "b"},
          {"a", "p"},
          {"b", "p"},
          {"a", "x"},
          {"x", "c"},
          {"p", "c"},
          {"c", "o"}
        ]
      }

      assert {:error, {:wfnet_not_block_structured, _}} = Powl.from_wfnet(net)
    end

    test "silent choice branches and place-to-place arcs are typed refusals" do
      skip = %{
        transitions: ["a", "t"],
        silent: ["t"],
        flow: [{"i", "a"}, {"i", "t"}, {"a", "o"}, {"t", "o"}]
      }

      assert {:error, {:unsupported_wfnet_construct, :silent_choice_branch}} =
               Powl.from_wfnet(skip)

      assert {:error, {:wfnet_place_to_place_arc, {"i", "o"}}} =
               Powl.from_wfnet(%{transitions: ["a"], flow: [{"i", "o"}]})

      assert {:error, {:unknown_silent_transition, "z"}} =
               Powl.from_wfnet(%{transitions: ["a"], flow: [], silent: ["z"]})

      assert {:error, :wfnet_no_visible_transition} =
               Powl.from_wfnet(%{transitions: ["t"], flow: [], silent: ["t"]})
    end

    test "non-label transitions are refused before any computation" do
      assert {:error, {:invalid_wfnet_transition, {1, 2}}} =
               Powl.from_wfnet(%{transitions: [{1, 2}], flow: []})

      assert {:error, {:invalid_wfnet_transition, nil}} =
               Powl.from_wfnet(%{transitions: ["a", nil], flow: []})
    end
  end

  describe "GALL-017 OCPQ verdict identity and object binding" do
    test "different queries with identical empty results have different result digests" do
      ocel = Corpus.fixture!("object-centric").ocel
      {:ok, left} = Ocpq.evaluate(ocel, %{activity: "never", require_match: false})
      {:ok, right} = Ocpq.evaluate(ocel, %{activity: "other", require_match: false})
      assert left.bindings == [] and right.bindings == []
      assert left.query_digest != right.query_digest
      assert left.result_digest != right.result_digest
      assert left.evaluator == Ocpq.evaluator()
    end

    test "after_activity binds only through a shared object" do
      events = [
        %{id: "e1", activity: "create", sequence: 1, objects: [{"order:1", "order", "target"}]},
        %{id: "e2", activity: "ship", sequence: 2, objects: [{"order:2", "order", "target"}]},
        %{id: "e3", activity: "ship", sequence: 3, objects: [{"order:1", "order", "target"}]}
      ]

      {:ok, result} =
        Ocpq.evaluate(%{events: events}, %{activity: "ship", after_activity: "create"})

      assert Enum.map(result.bindings, & &1.event_id) == ["e3"]
    end

    test "a non-integer sequence is refused, so every verdict is portable" do
      event = %{id: "e", activity: "a", sequence: 1.5, objects: []}

      assert {:error, {:invalid_ocel_event, ^event}} =
               Ocpq.evaluate(%{events: [event]}, %{activity: "a"})

      {:ok, selection} =
        Compute.select(:ocpq, %{ocel: %{events: [event]}, query: %{activity: "a"}})

      # The dispatcher refuses the non-portable input before compute.
      assert {:error, {:non_portable_compute, :input, {:float_not_in_portable_subset, 1.5}}} =
               Compute.execute(selection)
    end
  end

  describe "GALL-018 candidate set inside a rule envelope" do
    test "an underdetermined log yields multiple candidates and a typed ambiguity" do
      {:ok, result} = Discovery.discover([["a", "b"], ["b", "a"]], [])
      assert Enum.map(result.candidates, & &1.kind) |> Enum.sort() == [:concurrency, :dfg]
      assert [%{type: :underdetermined, pairs: [{"a", "b"}]}] = result.ambiguity
      assert result.standing == :candidate
    end

    test "a constraint eliminates the trace-fitting unlawful candidate and keeps the lawful one" do
      {:ok, result} =
        Discovery.discover([["a", "b", "c"], ["a", "c"]], [{:forbid_edge, "a", "c"}])

      assert result.standing == :candidate
      assert [%{kind: :rule_constrained} = lawful] = result.candidates
      refute {"a", "c"} in Enum.map(lawful.edges, &elem(&1, 0))
      assert lawful.fitness_bp == 5000

      assert [%{kind: :dfg, violations: [%{type: :forbidden_edge_in_candidate}]}] =
               result.eliminated

      # observed violation is a deviation, the rule is unchanged
      assert [%{type: :forbidden_edge_observed, edge: {"a", "c"}}] = result.deviations
    end

    test "changing the rule set changes the discovery subject; ranking is reproducible" do
      traces = [["a", "b", "c"], ["a", "c", "b"], ["a", "b", "c"]]
      {:ok, one} = Discovery.discover(traces, [])
      {:ok, again} = Discovery.discover(traces, [])
      {:ok, ruled} = Discovery.discover(traces, [{:require_edge, "a", "b"}])
      assert one == again
      assert one.discovery_digest != ruled.discovery_digest

      assert Enum.map(one.candidates, & &1.fitness_bp) ==
               Enum.sort(Enum.map(one.candidates, & &1.fitness_bp), :desc)
    end

    test "precedence semantics: every b needs an earlier a" do
      assert {:ok, %{deviations: [%{type: :ordering_violation}]}} =
               Discovery.discover([["b", "a", "b"]], [{:before, "a", "b"}])

      assert {:ok, %{deviations: []}} =
               Discovery.discover([["a", "b", "b"], ["a", "c", "b"]], [{:before, "a", "b"}])

      assert {:ok, %{deviations: []}} =
               Discovery.discover([["c"], ["a", "b", "a", "b"]], [{:before, "a", "b"}])
    end
  end

  describe "GALL-019 held-out evaluation, leakage falsifiers, model identity" do
    defp rows do
      for i <- 1..20 do
        risky = rem(i, 4) == 0
        label = if risky, do: :deviation, else: :conformant
        # channel predicts the label except for one noisy subject
        channel = if(risky != (i == 7), do: "manual", else: "api")

        %{
          subject_id: "s#{String.pad_leading(Integer.to_string(i), 2, "0")}",
          label: label,
          features: %{channel: channel, region: rem(i, 3)}
        }
      end
    end

    test "baseline and selected model are both reported with held-out metrics and FP/FN" do
      {:ok, report} = Compliance.evaluate(rows())
      assert report.baseline.model.kind == :majority_baseline
      assert report.one_rule.model.kind == :one_rule
      assert report.one_rule.model.feature == :channel
      assert report.selected_kind in [:majority_baseline, :one_rule]

      test_metrics = report.one_rule.test
      assert test_metrics.n > 0
      assert is_integer(test_metrics.accuracy_bp)

      for entry <- test_metrics.per_label do
        assert Map.keys(entry) |> Enum.sort() ==
                 [
                   :false_negative,
                   :false_positive,
                   :label,
                   :precision_bp,
                   :recall_bp,
                   :support,
                   :true_positive
                 ]
      end

      assert length(test_metrics.calibration) == 4
      assert {:ok, same} = Compliance.evaluate(rows())
      assert same.evaluation_digest == report.evaluation_digest

      assert {:ok, _} = Portable.build(:compliance_evaluation, report, attrs())
    end

    test "selected model beats the baseline on a feature-determined label" do
      clean =
        for i <- 1..30 do
          label = if rem(i, 3) == 0, do: :deviation, else: :conformant
          channel = if label == :deviation, do: "manual", else: "api"
          %{subject_id: "c#{i + 100}", label: label, features: %{channel: channel}}
        end

      {:ok, report} = Compliance.evaluate(clean)
      assert report.selected_kind == :one_rule
      assert report.one_rule.test.accuracy_bp > report.baseline.test.accuracy_bp
      assert Enum.any?(report.baseline.test.per_label, &(&1.false_negative > 0))
    end

    test "label and temporal leakage are refused before training" do
      leaky = Enum.map(rows(), &put_in(&1, [:features, :outcome], &1.label))
      assert {:error, {:label_leakage, :outcome}} = Compliance.evaluate(leaky)

      named = Enum.map(rows(), &put_in(&1, [:features, :label], "x"))
      assert {:error, {:label_leakage, :label}} = Compliance.train(named)

      [first | rest] = rows()
      late = Map.merge(first, %{features_at: 10, label_at: 10})
      assert {:error, {:temporal_leakage, "s01"}} = Compliance.train([late | rest])
    end

    test "a subject straddling splits is refused" do
      [a, b, c | _] = rows()
      assert {:error, {:subject_leakage, ["s01"]}} = Compliance.evaluate([a, b], [c], [a])
    end

    test "malformed rows and models are typed refusals, never raises" do
      assert {:error, {:invalid_training_row, %{subject_id: "a"}}} =
               Compliance.train([%{subject_id: "a"}])

      assert {:error, :empty_training_set} = Compliance.train([])
      assert {:error, :invalid_model} = Compliance.predict(%{model_digest: "x"}, "s", %{})
      assert {:error, :invalid_prediction_input} = Compliance.predict(%{}, :s, %{})
    end

    test "a model edited under its original digest is refused (FR5)" do
      {:ok, model} = Compliance.train(rows())
      forged = %{model | majority_label: :bad}
      assert {:error, :model_digest_mismatch} = Compliance.predict(forged, "s", %{})

      {:ok, selection} =
        Compute.select(:compliance_predict, %{model: forged, subject_id: "s", features: %{}})

      assert {:error, :model_digest_mismatch} = Compute.execute(selection)
    end

    test "threshold and model identity change the prediction subject" do
      {:ok, baseline} = Compliance.train(rows())
      {:ok, one_rule} = Compliance.train(rows(), kind: :one_rule)
      {:ok, low} = Compliance.predict(baseline, "s", %{channel: "api"}, threshold_bp: 0)
      {:ok, high} = Compliance.predict(baseline, "s", %{channel: "api"}, threshold_bp: 9_999)
      {:ok, other} = Compliance.predict(one_rule, "s", %{channel: "api"})
      assert low.predicted_label == :conformant
      assert high.predicted_label == :abstain
      assert low.prediction_digest != high.prediction_digest
      assert low.prediction_digest != other.prediction_digest
      assert low.authority == :none and low.standing == :candidate
    end
  end

  describe "GALL-020 dispatcher refuses malformed input and binds version" do
    test "malformed inputs refuse before compute" do
      cases = [
        {:compliance_predict,
         %{model: %{model_digest: "sha256:x"}, subject_id: "s", features: %{}}},
        {:powl_wfnet, %{transitions: [{1, 2}], flow: []}},
        {:powl_wfnet, %{transitions: "ab", flow: []}},
        {:discover, %{traces: "x", rules: []}},
        {:ocpq, %{ocel: %{events: :none}, query: %{}}},
        {:powl_semantic, "sequence"}
      ]

      for {capability, input} <- cases do
        {:ok, selection} = Compute.select(capability, input)
        assert {:error, _} = Compute.execute(selection), inspect({capability, input})
      end
    end

    test "algorithm version is bound into selection and receipt identity" do
      input = %{type: :sequence, children: ["a", "b"]}
      {:ok, selection} = Compute.select(:powl_semantic, input)
      assert selection.algorithm_version == Compute.version()
      {:ok, receipt} = Compute.execute(selection)
      assert is_binary(receipt.receipt_digest)

      # a selection carrying another version, even correctly re-digested, is
      # not silently executed under this version
      other = %{
        selection
        | algorithm_version: "v0",
          selection_digest: Compute.selection_digest(:powl_semantic, "v0", input)
      }

      assert other.selection_digest != selection.selection_digest
      assert {:error, {:algorithm_version_unavailable, "v0"}} = Compute.execute(other)

      # version shifted without re-digesting is a forged selection
      assert {:error, :selection_digest_mismatch} =
               Compute.execute(%{selection | algorithm_version: "v0"})
    end

    test "LLM-selected and direct callers get the same receipt identity" do
      input = Corpus.fixture!("choice").wfnet
      {:ok, via_select} = Compute.select(:powl_wfnet, input)
      {:ok, direct} = Compute.select(:powl_wfnet, input)
      {:ok, r1} = Compute.execute(via_select)
      {:ok, r2} = Compute.execute(direct)
      assert r1.receipt_digest == r2.receipt_digest
      assert {:ok, direct_result} = Powl.from_wfnet(input)
      assert r1.result == direct_result
    end
  end
end
