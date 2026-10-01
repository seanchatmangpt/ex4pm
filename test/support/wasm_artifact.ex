defmodule Ex4pm.Test.WasmArtifact do
  @moduledoc """
  Shared resolver for the real `wasm4pm_ex4pm_bindings.wasm` artifact used by
  the real-wasm test files (compiled via `elixirc_paths(:test)` /
  `test/support`).

  `path/0` resolution order (first candidate that exists on disk wins; if none
  exists the first configured candidate is returned so skip/failure messages
  name a real path):

    1. `EX4PM_WASM_ARTIFACT` env var
    2. `Application.get_env(:ex4pm, :wasm4pm_artifact)`
    3. bundled `Application.app_dir(:ex4pm, "priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm")`
    4. `/private/tmp/w4pm-artifact/wasm4pm_ex4pm_bindings.wasm`
    5. `~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm`

  `EX4PM_WASM_REQUIRED=1` turns a missing artifact into a hard failure
  (`skip_reason/0` raises) instead of a named skip.
  """

  @file_name "wasm4pm_ex4pm_bindings.wasm"

  @doc "Ordered, non-nil candidate artifact paths."
  @spec candidates() :: [String.t()]
  def candidates do
    env =
      case System.get_env("EX4PM_WASM_ARTIFACT") do
        v when v in [nil, ""] -> nil
        v -> Path.expand(v)
      end

    configured =
      case Application.get_env(:ex4pm, :wasm4pm_artifact) do
        v when is_binary(v) and v != "" -> Path.expand(v)
        _ -> nil
      end

    Enum.reject(
      [
        env,
        configured,
        bundled_path(),
        Path.join("/private/tmp/w4pm-artifact", @file_name),
        Path.expand("~/wasm4pm/target/wasm32-unknown-unknown/release/" <> @file_name)
      ],
      &is_nil/1
    )
  end

  @doc "Resolved artifact path (see moduledoc for order)."
  @spec path() :: String.t()
  def path do
    cs = candidates()
    Enum.find(cs, &File.regular?/1) || hd(cs)
  end

  @doc "True when the resolved artifact exists as a regular file."
  @spec available?() :: boolean()
  def available?, do: File.regular?(path())

  @doc "True when `EX4PM_WASM_REQUIRED=1`."
  @spec required?() :: boolean()
  def required?, do: System.get_env("EX4PM_WASM_REQUIRED") == "1"

  @doc """
  `nil` when the artifact is available (nothing to skip). When absent: a skip
  reason string, or -- under `EX4PM_WASM_REQUIRED=1` -- raises so absence FAILS.
  """
  @spec skip_reason() :: String.t() | nil
  def skip_reason do
    cond do
      available?() ->
        nil

      required?() ->
        raise "REFUSED_ARTIFACT_MISSING: EX4PM_WASM_REQUIRED=1 but wasm artifact absent: " <>
                "#{path()} (tried: #{Enum.join(candidates(), ", ")})"

      true ->
        "wasm artifact not built: #{path()} (EX4PM_WASM_REQUIRED=1 to fail)"
    end
  end

  @doc "Lower-case hex sha256 of the resolved artifact bytes."
  @spec sha256() :: String.t()
  def sha256, do: :crypto.hash(:sha256, File.read!(path())) |> Base.encode16(case: :lower)

  @doc """
  Digest pin for `RealTransport.start/2`: `EX4PM_WASM_SHA256` when set, else the
  artifact's own sha256 (these tests prove the ABI transport, not provenance).
  """
  @spec pin() :: String.t()
  def pin do
    case System.get_env("EX4PM_WASM_SHA256") do
      v when v in [nil, ""] -> sha256()
      v -> v
    end
  end

  defp bundled_path do
    Application.app_dir(:ex4pm, Path.join("priv/wasm4pm", @file_name))
  rescue
    _ -> nil
  end

  @doc """
  Canonical request per registered algorithm (all 33), shared by the
  all-capabilities Reactor test and the replay coverage test.
  """
  @spec canonical_requests() :: %{atom() => map()}
  def canonical_requests do
    %{
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
  end
end
