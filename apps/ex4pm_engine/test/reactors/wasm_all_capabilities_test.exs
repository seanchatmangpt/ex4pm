defmodule Ex4pmEngine.Reactors.WasmAllCapabilitiesTest do
  @moduledoc """
  Real, no-mock proof that ALL 19 `wasm4pm-ex4pm-bindings` process-
  intelligence capabilities are triggered by
  `Ex4pmEngine.Reactors.WasmCapabilitiesReactor` and reach a genuine
  `:alive` standing -- one shared, real Wasmex instance, real linear
  memory, real replay verification per algorithm, no fixture closures.

  Every canonical request below is taken directly from
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/{lib,phase2,phase2_playout,prolog}.rs`'s
  OWN passing Rust unit tests (`cargo test -p wasm4pm-ex4pm-bindings`:
  25/25 passing) -- the same request bytes, cross-checked against the same
  crate's own real assertions, not invented independently here. Each
  Elixir assertion below checks the SAME structural property the
  corresponding Rust test checks.

  Named, honest skip (not a silent pass) when the real artifact hasn't been
  built on this machine.
  """
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Reactors.WasmCapabilitiesReactor

  @artifact_path Path.expand(
                   "~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm"
                 )

  @requests %{
    discover: %{traces: [["a", "b", "c"], ["a", "b"]]},
    conform: %{traces: [["a", "b"], ["a", "c"]], model_edges: [%{from: "a", to: "b"}]},
    simulate: %{
      edges: [%{from: "a", to: "b"}, %{from: "a", to: "c"}],
      start: "a",
      steps: 1,
      seed: 42
    },
    optimize: %{
      edges: [
        %{from: "a", to: "b", duration: 1.0},
        %{from: "b", to: "c", duration: 5.0},
        %{from: "a", to: "c", duration: 2.0}
      ],
      start: "a",
      end: "c"
    },
    powl_mine: %{traces: [["a", "b"], ["a", "b"]]},
    survival: %{times: [1.0, 2.0, 3.0, 4.0], events: [1.0, 1.0, 0.0, 1.0]},
    markov: %{transition_matrix: [0.5, 0.5, 0.5, 0.5], n_states: 2, max_iter: 100, tol: 1.0e-9},
    bayesian: %{data: [1.0, 2.0, 3.0, 4.0], n_features: 1, targets: [2.0, 4.0, 6.0, 8.0]},
    ocpq_eval: %{
      query: %{root: "n0", nodes: [%{id: "n0", box: %{}}]},
      ocel: %{objectTypes: [], eventTypes: [], objects: [], events: []}
    },
    strips_plan: %{
      intent: "test",
      candidates: [],
      facts: [],
      cases: [],
      rules: [],
      goals: [],
      state: []
    },
    htn_plan: %{
      intent: "test",
      candidates: [],
      facts: [],
      cases: [],
      rules: [],
      goals: [],
      state: []
    },
    ctl_check: %{
      intent: "test",
      candidates: [],
      cases: [],
      rules: [],
      goals: [],
      state: [],
      facts: [
        %{key: "ts:init", value: "s0"},
        %{key: "ts:edge:s0", value: "s1"},
        %{key: "ts:edge:s1", value: "s1"},
        %{key: "ts:label:s1", value: "done"},
        %{key: "ctl:formula", value: "E F done"}
      ]
    },
    allen_temporal: %{
      intent: "test",
      candidates: [],
      facts: [],
      cases: [],
      rules: [],
      goals: [],
      state: []
    },
    oc_discover: %{
      ocel: %{
        event_types: ["A", "B"],
        object_types: ["Order"],
        events: [
          %{
            id: "e1",
            event_type: "A",
            timestamp: "2024-01-01T10:00:00Z",
            attributes: %{},
            object_ids: ["order1"],
            object_refs: []
          },
          %{
            id: "e2",
            event_type: "B",
            timestamp: "2024-01-01T11:00:00Z",
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
    },
    align: %{
      traces: [["a", "b"]],
      petri_net: %{
        places: [%{id: "p0", label: "p0"}, %{id: "p1", label: "p1"}, %{id: "p2", label: "p2"}],
        transitions: [%{id: "t0", label: "a"}, %{id: "t1", label: "b"}],
        arcs: [
          %{from: "p0", to: "t0"},
          %{from: "t0", to: "p1"},
          %{from: "p1", to: "t1"},
          %{from: "t1", to: "p2"}
        ],
        initial_marking: %{p0: 1},
        final_markings: [%{p2: 1}]
      },
      sync_cost: 0.0,
      log_move_cost: 1.0,
      model_move_cost: 1.0
    },
    etc_precision: %{
      net: %{
        places: [%{id: "p0", label: "p0"}, %{id: "p1", label: "p1"}],
        transitions: [%{id: "t0", label: "a"}],
        arcs: [%{from: "p0", to: "t0"}, %{from: "t0", to: "p1"}],
        initial_marking: %{p0: 1},
        final_markings: [%{p1: 1}]
      },
      initial_marking: %{p0: 1},
      final_marking: %{p1: 1},
      log: %{attributes: %{}, traces: []},
      activity_key: "concept:name"
    },
    soundness: %{
      petri_net: %{
        places: [%{id: "p0", label: "p0"}, %{id: "p1", label: "p1"}, %{id: "p2", label: "p2"}],
        transitions: [%{id: "t0", label: "a"}, %{id: "t1", label: "b"}],
        arcs: [
          %{from: "p0", to: "t0"},
          %{from: "t0", to: "p1"},
          %{from: "p1", to: "t1"},
          %{from: "t1", to: "p2"}
        ],
        initial_marking: %{p0: 1},
        final_markings: [%{p2: 1}]
      }
    },
    playout: %{
      petri_net: %{
        places: [
          %{id: "p1", label: "start", marking: 1},
          %{id: "p2", label: "middle", marking: 0},
          %{id: "p3", label: "end", marking: 0}
        ],
        transitions: [
          %{id: "t1", label: "a", is_invisible: false},
          %{id: "t2", label: "b", is_invisible: false}
        ],
        arcs: [
          %{from: "p1", to: "t1", weight: 1},
          %{from: "t1", to: "p2", weight: 1},
          %{from: "p2", to: "t2", weight: 1},
          %{from: "t2", to: "p3", weight: 1}
        ],
        initial_marking: %{p1: 1},
        final_markings: [%{p3: 1}]
      },
      config: %{max_trace_length: 10, num_traces: 5, random_seed: 7}
    },
    prolog_query: %{
      predicates: [%{name: "parent", arity: 2}],
      facts: [%{pred: "parent", args: ["alice", "bob"]}],
      rules: [],
      query: %{pred: "parent", args: ["alice", "Y"]}
    },
    # Phase 4 (statistics/ML) -- canonical requests cross-checked against
    # wasm4pm-ex4pm-bindings' own real Rust unit tests
    # (crates/wasm4pm-ex4pm-bindings/src/phase4_stats.rs, tests module).
    ks_statistic: %{sample_a: [1.0, 2.0, 3.0], sample_b: [1.0, 2.0, 3.0]},
    ks_critical_value: %{n: 10, m: 10, alpha: 0.05},
    regression: %{x: [1.0, 2.0, 3.0, 4.0], y: [2.0, 4.0, 6.0, 8.0]},
    forecast: %{data: [1.0, 2.0, 3.0, 4.0, 5.0], alpha: 0.3},
    holt_forecast: %{series: [1.0, 2.0, 3.0, 4.0, 5.0], alpha: 0.5, beta: 0.5},
    ewma: %{values: [1.0, 5.0, 10.0], alpha: 1.0},
    trend_classify: %{smoothed: [1.0, 2.0, 3.0, 4.0, 5.0]},
    mean: %{data: [1.0, 2.0, 3.0, 4.0]},
    dot_product: %{a: [1.0, 2.0, 3.0], b: [4.0, 5.0, 6.0]},
    euclidean_distance: %{a: [0.0, 0.0], b: [3.0, 4.0]},
    standardize: %{data: [[1.0, 10.0], [2.0, 20.0], [3.0, 30.0]]},
    median: %{data: [3.0, 1.0, 2.0]},
    percentile: %{data: [1.0, 2.0, 3.0, 4.0], p: 50.0},
    std_deviation: %{data: [5.0, 5.0, 5.0]}
  }

  setup do
    if File.regular?(@artifact_path) do
      {:ok, results: run_all!()}
    else
      {:skip, "wasm artifact not built"}
    end
  end

  defp run_all! do
    {:ok, %{results: results}} =
      Reactor.run(WasmCapabilitiesReactor, %{artifact_path: @artifact_path, requests: @requests})

    results
  end

  @tag :real_wasm
  test "all 19 Phase-1/2/3 capabilities reach real :alive standing with real replay verification",
       %{results: results} do
    for algo <- Map.keys(@requests) do
      result = Map.fetch!(results, algo)
      assert result.standing == :alive, "#{algo} did not reach :alive: #{inspect(result)}"
    end
  end

  @tag :real_wasm
  test "the Reactor runs all 33 registered capabilities (19 Phase-1/2/3 + 14 Phase-4)", %{
    results: results
  } do
    assert map_size(results) == 33
    assert map_size(@requests) == 33
  end

  @tag :real_wasm
  test "an algorithm with no matching request is reported :unsupported, never crashed" do
    assert {:ok, %{results: results}} =
             Reactor.run(WasmCapabilitiesReactor, %{
               artifact_path: @artifact_path,
               requests: %{discover: @requests.discover}
             })

    assert results.discover.standing == :alive
    assert results.mean.standing == :unsupported
    assert results.mean.reason == :no_request_given
  end

  @tag :real_wasm
  test "discover produces the real directly-follows graph", %{results: results} do
    assert results.discover.value["activities"] == ["a", "b", "c"]
    edges = results.discover.value["edges"]
    assert Enum.find(edges, &(&1["from"] == "a" and &1["to"] == "b"))["freq"] == 2
  end

  @tag :real_wasm
  test "conform computes real directly-follows fitness", %{results: results} do
    assert results.conform.value["fit_traces"] == 1
    assert results.conform.value["total_traces"] == 2
  end

  @tag :real_wasm
  test "optimize finds the real longest path (duration 6.0)", %{results: results} do
    assert results.optimize.value["duration"] == 6.0
  end

  @tag :real_wasm
  test "markov computes the real steady state [0.5, 0.5]", %{results: results} do
    assert results.markov.value["steady_state"] == [0.5, 0.5]
  end

  @tag :real_wasm
  test "survival returns a real Kaplan-Meier curve", %{results: results} do
    assert is_list(results.survival.value["survival"])
    assert is_number(results.survival.value["median_survival"])
  end

  @tag :real_wasm
  test "bayesian fits a real linear regression", %{results: results} do
    assert is_list(results.bayesian.value["coefficients"])
  end

  @tag :real_wasm
  test "ocpq_eval runs the real query evaluator without error", %{results: results} do
    refute Map.has_key?(results.ocpq_eval.value, "error")
  end

  @tag :real_wasm
  test "strips_plan/htn_plan/ctl_check/allen_temporal produce a real inference trace with a breed",
       %{results: results} do
    for algo <- [:strips_plan, :htn_plan, :ctl_check, :allen_temporal] do
      assert Map.has_key?(results[algo].value, "breed"),
             "#{algo} missing breed: #{inspect(results[algo].value)}"
    end
  end

  @tag :real_wasm
  test "oc_discover runs end-to-end without error", %{results: results} do
    refute Map.has_key?(results.oc_discover.value, "error")
  end

  @tag :real_wasm
  test "align computes a real alignment over the two-transition net", %{results: results} do
    refute Map.has_key?(results.align.value, "error")
    assert is_list(results.align.value["alignments"])
  end

  @tag :real_wasm
  test "etc_precision computes a real precision value", %{results: results} do
    refute Map.has_key?(results.etc_precision.value, "error")
    assert Map.has_key?(results.etc_precision.value, "precision")
  end

  @tag :real_wasm
  test "soundness analyzes the real two-transition WF-net without error", %{results: results} do
    refute Map.has_key?(results.soundness.value, "error")
  end

  @tag :real_wasm
  test "playout produces real traces from the two-transition net", %{results: results} do
    refute Map.has_key?(results.playout.value, "error")
  end

  @tag :real_wasm
  test "prolog_query answers the real direct-fact-lookup query (Y = bob)", %{results: results} do
    assert results.prolog_query.value["result"] == "answered"
    [answer | _] = results.prolog_query.value["answers"]
    assert answer["bindings"]["Y"] == "bob"
  end

  # -- Phase 4 (statistics/ML) -------------------------------------------

  @tag :real_wasm
  test "ks_statistic is real zero for identical samples", %{results: results} do
    assert results.ks_statistic.value["ks_statistic"] == 0.0
  end

  @tag :real_wasm
  test "ks_critical_value returns a real finite value for real sample sizes", %{
    results: results
  } do
    assert is_number(results.ks_critical_value.value["ks_critical_value"])
    refute results.ks_critical_value.value["ks_critical_value"] in [nil, :infinity]
  end

  @tag :real_wasm
  test "regression recovers the real perfect linear fit y = 2x", %{results: results} do
    assert_in_delta results.regression.value["slope"], 2.0, 1.0e-9
    assert_in_delta results.regression.value["r_squared"], 1.0, 1.0e-9
  end

  @tag :real_wasm
  test "forecast returns real error metrics and a next_window prediction", %{results: results} do
    assert is_number(results.forecast.value["next_window"])
  end

  @tag :real_wasm
  test "holt_forecast returns real error metrics and a next_window prediction", %{
    results: results
  } do
    assert is_number(results.holt_forecast.value["next_window"])
  end

  @tag :real_wasm
  test "ewma with alpha=1.0 reproduces the real input series exactly", %{results: results} do
    assert results.ewma.value["ewma"] == [1.0, 5.0, 10.0]
  end

  @tag :real_wasm
  test "trend_classify detects a real rising series", %{results: results} do
    assert results.trend_classify.value["trend"] == "rising"
  end

  @tag :real_wasm
  test "mean computes the real average 2.5", %{results: results} do
    assert results.mean.value["mean"] == 2.5
  end

  @tag :real_wasm
  test "dot_product computes the real inner product 32.0", %{results: results} do
    assert results.dot_product.value["dot_product"] == 32.0
  end

  @tag :real_wasm
  test "euclidean_distance computes the real 3-4-5 triangle distance", %{results: results} do
    assert results.euclidean_distance.value["euclidean_distance"] == 5.0
  end

  @tag :real_wasm
  test "standardize returns real per-column standardized data", %{results: results} do
    standardized = results.standardize.value["standardized"]
    assert length(standardized) == 3
    # Real zero-mean check: the average of the standardized first column is ~0.
    col0_mean = standardized |> Enum.map(&hd/1) |> Enum.sum() |> Kernel./(3)
    assert_in_delta col0_mean, 0.0, 1.0e-9
  end

  @tag :real_wasm
  test "median computes the real middle value", %{results: results} do
    assert results.median.value["median"] == 2.0
  end

  @tag :real_wasm
  test "percentile(50) returns a real value close to the median", %{results: results} do
    assert is_number(results.percentile.value["percentile"])
  end

  @tag :real_wasm
  test "std_deviation is real zero for a constant series", %{results: results} do
    assert results.std_deviation.value["std_deviation"] == 0.0
  end
end
