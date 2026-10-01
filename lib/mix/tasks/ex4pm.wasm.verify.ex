defmodule Ex4pm.Wasm.Verify do
  @moduledoc """
  Verification court for the bundled wasm4pm artifact: admits the artifact bytes against
  the `priv/wasm4pm/MANIFEST.json` pin (`Ex4pmEngine.Wasm.Admission`), then executes one
  canonical request through every one of the 33 registered algorithm engines
  (`engine: :wasm_<algo>`) and reports a per-algorithm table.

  `run/1` returns `{:ok, report}` only when admission passed and every algorithm executed
  with standing `:alive | :partial_alive`; otherwise `{:error, report}` where
  `report.refusal` is one of `:no_artifact`, `{:admission, code}`, `{:algorithms, ids}`.

  Options: `:artifact_path` (default: the supervised Host's resolved path). With an explicit
  path a private instance is started via `Ex4pmEngine.Wasm.RealTransport`.
  """

  alias Ex4pm.Refusal
  alias Ex4pmEngine.Wasm.{AlgoRegistry, Admission, Host, RealTransport}

  @type row :: %{id: atom(), standing: atom() | nil, status: :ok | {:refused, atom()}}
  @type report :: %{
          path: String.t(),
          sha256: String.t() | nil,
          pin_sha256: String.t() | nil,
          admitted: boolean(),
          rows: [row()],
          refusal: nil | :no_artifact | {:admission, atom()} | {:algorithms, [atom()]}
        }

  @doc "Runs the court; see the module doc."
  @spec run(keyword()) :: {:ok, report()} | {:error, report()}
  def run(opts \\ []) do
    pin = Admission.manifest_sha256()
    path = Keyword.get(opts, :artifact_path) || Host.artifact_path()

    base = %{
      path: path,
      sha256: nil,
      pin_sha256: pin,
      admitted: false,
      rows: [],
      refusal: nil
    }

    case File.read(path) do
      {:error, _} ->
        {:error, %{base | refusal: :no_artifact}}

      {:ok, bytes} ->
        base = %{base | sha256: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)}

        case Admission.admit(bytes, expected_sha256: pin) do
          {:error, %Refusal{code: code}} ->
            {:error, %{base | refusal: {:admission, code}}}

          {:ok, _} ->
            execute_all(%{base | admitted: true}, opts)
        end
    end
  end

  defp execute_all(base, opts) do
    case transport_opts(base, opts) do
      {:error, code} ->
        {:error, %{base | refusal: {:admission, code}}}

      {:ok, transports} ->
        rows = Enum.map(AlgoRegistry.algorithm_ids(), &execute_one(&1, transports))
        failed = for %{status: {:refused, _}, id: id} <- rows, do: id
        base = %{base | rows: rows}

        if failed == [],
          do: {:ok, base},
          else: {:error, %{base | refusal: {:algorithms, failed}}}
    end
  end

  # No explicit artifact: the supervised Host supplies the transport (Adapter fallback).
  defp transport_opts(_base, opts) do
    case Keyword.fetch(opts, :artifact_path) do
      :error ->
        {:ok, []}

      {:ok, path} ->
        case RealTransport.all_transports(path, expected_sha256: Admission.manifest_sha256()) do
          {:ok, transports} -> {:ok, transports}
          {:error, %Refusal{code: code}} -> {:error, code}
          {:error, _} -> {:error, :wasm_host_boot_failed}
        end
    end
  end

  defp execute_one(id, transports) do
    request = Map.fetch!(requests(), id)

    case Ex4pm.Engine.execute(id, request, [engine: :"wasm_#{id}"] ++ transports) do
      {:ok, %Ex4pm.Engine.Result{standing: standing}} when standing in [:alive, :partial_alive] ->
        %{id: id, standing: standing, status: :ok}

      {:ok, %Ex4pm.Engine.Result{standing: standing}} ->
        %{id: id, standing: standing, status: {:refused, :unexpected_standing}}

      {:error, %Refusal{code: code}} ->
        %{id: id, standing: nil, status: {:refused, code}}

      {:error, _} ->
        %{id: id, standing: nil, status: {:refused, :engine_error}}
    end
  end

  @doc "One canonical request per registered algorithm (all 33), keyed by `algorithm_id`."
  @spec requests() :: %{atom() => map()}
  def requests do
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

defmodule Mix.Tasks.Ex4pm.Wasm.Verify do
  @moduledoc """
  Admits the bundled wasm4pm artifact and executes a canonical request through all 33
  algorithm engines.

      mix ex4pm.wasm.verify
      mix ex4pm.wasm.verify --artifact path/to/wasm4pm_ex4pm_bindings.wasm

  Prints a per-algorithm table and exits non-zero (via `Mix.raise/1`) on failure.

  Refusals (typed in the message prefix):

    * `REFUSED_NO_ARTIFACT` -- the artifact file is absent.
    * `REFUSED_ADMISSION` -- digest pin, import surface or required exports refused
      (the `Ex4pmEngine.Wasm.Admission` code follows).
    * `REFUSED_ALGORITHMS` -- one or more algorithm engines did not execute.
  """
  use Mix.Task

  @shortdoc "Admits the wasm4pm artifact and runs all 33 algorithms"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [artifact: :string])
    Mix.Task.run("app.start")
    run_opts = if opts[:artifact], do: [artifact_path: Path.expand(opts[:artifact])], else: []

    {verdict, report} = Ex4pm.Wasm.Verify.run(run_opts)
    print(report)

    case {verdict, report.refusal} do
      {:ok, _} ->
        Mix.shell().info("mix ex4pm.wasm.verify: ok (#{length(report.rows)} algorithms)")
        :ok

      {:error, :no_artifact} ->
        Mix.raise("REFUSED_NO_ARTIFACT: wasm4pm artifact not found at #{report.path}")

      {:error, {:admission, code}} ->
        Mix.raise("REFUSED_ADMISSION: #{code} (#{report.path})")

      {:error, {:algorithms, ids}} ->
        Mix.raise("REFUSED_ALGORITHMS: #{Enum.map_join(ids, ", ", &Atom.to_string/1)}")
    end
  end

  defp print(report) do
    Mix.shell().info("artifact #{report.path}")
    Mix.shell().info("sha256   #{report.sha256}")
    Mix.shell().info("pin      #{report.pin_sha256}")
    Mix.shell().info("admitted #{report.admitted}")

    for row <- report.rows do
      status =
        case row.status do
          :ok -> "ok"
          {:refused, code} -> "REFUSED #{code}"
        end

      Mix.shell().info(
        "  #{String.pad_trailing(Atom.to_string(row.id), 22)} #{String.pad_trailing(to_string(row.standing), 14)} #{status}"
      )
    end
  end
end
