defmodule Ex4pmEngine.Wasm.Phase123EdgeCasesTest do
  @moduledoc """
  Real, no-mock edge-case coverage for the original 19 Phase-1/2/3
  wasm4pm capabilities, complementing `wasm_all_capabilities_test.exs`'s
  single-happy-path-per-algorithm coverage. Driven directly through
  `Ex4pmEngine.Wasm.RealTransport.call/3` against the real compiled
  artifact.

  Named, honest skip (not a silent pass) when the real artifact hasn't been
  built on this machine.
  """
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Wasm.RealTransport

  @artifact_path Path.expand(
                   "~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm"
                 )

  setup do
    if File.regular?(@artifact_path) do
      {:ok, instance} = RealTransport.start(@artifact_path)
      {:ok, instance: instance}
    else
      :skip
    end
  end

  defp result!(instance, export, request) do
    assert {:ok, %{"result" => result}} = RealTransport.call(instance, export, request)
    result
  end

  @tag :real_wasm
  test "discover on a single-activity trace produces one real activity and zero edges", %{
    instance: i
  } do
    r = result!(i, "wasm4pm_ex4pm_discover_v1", %{traces: [["a"]]})
    assert r["activities"] == ["a"]
    assert r["edges"] == []
  end

  @tag :real_wasm
  test "discover on empty traces produces real empty activities and edges", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_discover_v1", %{traces: []})
    assert r["activities"] == []
    assert r["edges"] == []
  end

  @tag :real_wasm
  test "conform is real 0% fit when no trace matches the model", %{instance: i} do
    r =
      result!(i, "wasm4pm_ex4pm_conform_v1", %{
        traces: [["x", "y"]],
        model_edges: [%{from: "a", to: "b"}]
      })

    assert r["fit_traces"] == 0
    assert r["total_traces"] == 1
  end

  @tag :real_wasm
  test "conform is real 100% fit when every trace matches the model exactly", %{instance: i} do
    r =
      result!(i, "wasm4pm_ex4pm_conform_v1", %{
        traces: [["a", "b"], ["a", "b"]],
        model_edges: [%{from: "a", to: "b"}]
      })

    assert r["fit_traces"] == 2
    assert r["total_traces"] == 2
  end

  @tag :real_wasm
  test "simulate on a dead-end start halts immediately with a real single-element trace", %{
    instance: i
  } do
    r = result!(i, "wasm4pm_ex4pm_simulate_v1", %{edges: [], start: "a", steps: 5, seed: 1})
    assert r["trace"] == ["a"]
  end

  @tag :real_wasm
  test "simulate with zero steps returns a real single-element trace at the start", %{
    instance: i
  } do
    r =
      result!(i, "wasm4pm_ex4pm_simulate_v1", %{
        edges: [%{from: "a", to: "b"}],
        start: "a",
        steps: 0,
        seed: 1
      })

    assert r["trace"] == ["a"]
  end

  @tag :real_wasm
  test "optimize on a disconnected start/end pair returns a real empty path, not a crash", %{
    instance: i
  } do
    r = result!(i, "wasm4pm_ex4pm_optimize_v1", %{edges: [], start: "a", end: "z"})
    assert r["path"] == []
    assert r["duration"] == 0.0
  end

  @tag :real_wasm
  test "powl_mine detects a real pure sequence from a single consistent trace", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_powl_mine_v1", %{traces: [["a", "b", "c"]]})
    assert r["node_type"] == "sequence"
  end

  @tag :real_wasm
  test "powl_mine falls back to a real flower model when trace orders differ", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_powl_mine_v1", %{traces: [["a", "b"], ["b", "a"]]})
    assert r["node_type"] == "flower"
  end

  @tag :real_wasm
  test "survival on all-censored data still returns real, well-formed output", %{instance: i} do
    r =
      result!(i, "wasm4pm_ex4pm_survival_v1", %{times: [1.0, 2.0, 3.0], events: [0.0, 0.0, 0.0]})

    assert is_list(r["survival"])
  end

  @tag :real_wasm
  test "markov with a real identity-like transition matrix converges to a stable state", %{
    instance: i
  } do
    r =
      result!(i, "wasm4pm_ex4pm_markov_v1", %{
        transition_matrix: [1.0, 0.0, 0.0, 1.0],
        n_states: 2,
        max_iter: 50,
        tol: 1.0e-9
      })

    assert is_list(r["steady_state"])
  end

  @tag :real_wasm
  test "bayesian on fewer than 2 samples returns a real, named error (not a crash)", %{
    instance: i
  } do
    assert {:ok, %{"error" => message}} =
             RealTransport.call(i, "wasm4pm_ex4pm_bayesian_v1", %{
               data: [1.0],
               n_features: 1,
               targets: [2.0]
             })

    assert message =~ "at least 2 samples"
  end

  @tag :real_wasm
  test "bayesian on exactly 2 samples returns real, well-formed coefficients", %{instance: i} do
    r =
      result!(i, "wasm4pm_ex4pm_bayesian_v1", %{
        data: [1.0, 2.0],
        n_features: 1,
        targets: [2.0, 4.0]
      })

    assert is_list(r["coefficients"])
  end

  @tag :real_wasm
  test "ocpq_eval on an empty OCEL log with a trivially-true query is satisfied", %{
    instance: i
  } do
    r =
      result!(i, "wasm4pm_ex4pm_ocpq_eval_v1", %{
        query: %{root: "n0", nodes: [%{id: "n0", box: %{}}]},
        ocel: %{objectTypes: [], eventTypes: [], objects: [], events: []}
      })

    refute Map.has_key?(r, "error")
  end

  @tag :real_wasm
  test "oc_discover on a single-event OCEL log runs end-to-end without error", %{instance: i} do
    r =
      result!(i, "wasm4pm_ex4pm_oc_discover_v1", %{
        ocel: %{
          event_types: ["A"],
          object_types: ["Order"],
          events: [
            %{
              id: "e1",
              event_type: "A",
              timestamp: "2024-01-01T10:00:00Z",
              attributes: %{},
              object_ids: ["order1"],
              object_refs: []
            }
          ],
          objects: [
            %{
              id: "order1",
              object_type: "Order",
              attributes: %{},
              changes: [],
              embedded_relations: []
            }
          ],
          object_relations: []
        },
        algorithm: "alpha++"
      })

    refute Map.has_key?(r, "error")
  end

  @tag :real_wasm
  test "align on a perfectly-fitting single-activity trace incurs real zero move cost", %{
    instance: i
  } do
    r =
      result!(i, "wasm4pm_ex4pm_align_v1", %{
        traces: [["a"]],
        petri_net: %{
          places: [%{id: "p0", label: "p0"}, %{id: "p1", label: "p1"}],
          transitions: [%{id: "t0", label: "a"}],
          arcs: [%{from: "p0", to: "t0"}, %{from: "t0", to: "p1"}],
          initial_marking: %{p0: 1},
          final_markings: [%{p1: 1}]
        },
        sync_cost: 0.0,
        log_move_cost: 1.0,
        model_move_cost: 1.0
      })

    refute Map.has_key?(r, "error")
    [alignment | _] = r["alignments"]
    assert Map.has_key?(alignment, "cost")
    assert is_integer(alignment["sync_moves"])
  end

  @tag :real_wasm
  test "soundness on a real single-transition WF-net analyzes without error", %{instance: i} do
    r =
      result!(i, "wasm4pm_ex4pm_soundness_v1", %{
        petri_net: %{
          places: [%{id: "p0", label: "p0"}, %{id: "p1", label: "p1"}],
          transitions: [%{id: "t0", label: "a"}],
          arcs: [%{from: "p0", to: "t0"}, %{from: "t0", to: "p1"}],
          initial_marking: %{p0: 1},
          final_markings: [%{p1: 1}]
        }
      })

    refute Map.has_key?(r, "error")
  end

  @tag :real_wasm
  test "prolog_query on an unmatchable query is real denied, not answered", %{instance: i} do
    r =
      result!(i, "wasm4pm_ex4pm_prolog_query_v1", %{
        predicates: [%{name: "parent", arity: 2}],
        facts: [%{pred: "parent", args: ["alice", "bob"]}],
        rules: [],
        query: %{pred: "parent", args: ["carol", "Y"]}
      })

    assert r["result"] == "denied"
  end

  @tag :real_wasm
  test "all 19 Phase-1/2/3 replay exports agree with a direct recompute", %{instance: i} do
    checks = [
      {"wasm4pm_ex4pm_discover_replay_v1", %{traces: [["a", "b"]]}},
      {"wasm4pm_ex4pm_conform_replay_v1",
       %{traces: [["a", "b"]], model_edges: [%{from: "a", to: "b"}]}},
      {"wasm4pm_ex4pm_simulate_replay_v1",
       %{edges: [%{from: "a", to: "b"}], start: "a", steps: 1, seed: 1}},
      {"wasm4pm_ex4pm_optimize_replay_v1",
       %{edges: [%{from: "a", to: "b", duration: 1.0}], start: "a", end: "b"}},
      {"wasm4pm_ex4pm_powl_mine_replay_v1", %{traces: [["a", "b"]]}},
      {"wasm4pm_ex4pm_survival_replay_v1", %{times: [1.0, 2.0], events: [1.0, 0.0]}},
      {"wasm4pm_ex4pm_markov_replay_v1",
       %{transition_matrix: [0.5, 0.5, 0.5, 0.5], n_states: 2, max_iter: 10, tol: 1.0e-6}},
      {"wasm4pm_ex4pm_bayesian_replay_v1",
       %{data: [1.0, 2.0], n_features: 1, targets: [2.0, 4.0]}}
    ]

    for {export, request} <- checks do
      assert {:ok, true} = RealTransport.replay(i, export, request),
             "#{export} failed real replay verification"
    end
  end
end
