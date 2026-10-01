defmodule Ex4pm.Run do
  @moduledoc "Public evidence envelope for an analytical ex4pm operation."
  @enforce_keys [:operation, :subject_hash, :standing, :value, :receipt]
  defstruct [
    :operation,
    :subject_hash,
    :standing,
    :value,
    :receipt,
    :pending,
    :engine_result,
    projections: []
  ]

  @type t :: %__MODULE__{
          operation: atom(),
          subject_hash: String.t(),
          standing: atom(),
          value: term(),
          receipt: term(),
          pending: term(),
          engine_result: Ex4pm.Engine.Result.t() | nil,
          projections: list()
        }
end

defmodule Ex4pm do
  @moduledoc """
  Public orchestration API for BEAM-native process intelligence.

  Every analytical function (`discover/2`, `conform/3`, `simulate/2`, `optimize/3`,
  `plan/2`, `cmca/2`, `ferroplan/3`, `statistics/3`, `forecast/2`) is CONSTRUCT-only: it
  runs an engine, then records a pending and an outcome receipt through
  `Ex4pm.Evidence.Store` and returns `{:ok, %Ex4pm.Run{}}` or `{:error, %Ex4pm.Refusal{}}`.
  Only `operate/3` crosses the BRCE/DO boundary.

  ## Common options

  | option | meaning |
  |---|---|
  | `:engine` | explicit engine id (e.g. `:beam`, `:wasm_discover`, `:ferroplan`); an explicit engine never silently falls back |
  | `:store` | evidence store (default `Ex4pm.Evidence.Store`) |
  | `:project?` | also project the run into the Ash-free domain projection (default `false`) |
  | `:<algo>_wasm_fun` | explicit 2-arity wasm transport for algorithm `<algo>`; absent, the supervised `Ex4pmEngine.Wasm.Host` supplies one |
  | `:wasm_default` | `false` disables the Host transport fallback |
  | `:prefer_wasm` | `true` lets Host-backed `:wasm_discover`/`:wasm_conform`/`:wasm_simulate`/`:wasm_optimize` outrank `:beam` |
  | `:ferroplan_artifact`, `:ferroplan_expected_sha256` | ferroplan wasm path / admitted digest pin |

  ## Standing and refusals

  Standing is one of `:unknown | :partial_alive | :alive | :blocked | :build_broken |
  :unsupported`; refusals are typed `%Ex4pm.Refusal{code: atom}`. Inspection
  (`capabilities/2`, `wasm/1`) is never execution; `health/1` executes a probe only
  when `probe: true` (the default).
  """

  @type run_result :: {:ok, Ex4pm.Run.t()} | {:error, Refusal.t()}

  alias Ex4pm.Domain.Projector
  alias Ex4pm.Engine
  alias Ex4pm.Engine.Differential
  alias Ex4pm.Evidence.{Receipt, Store}
  alias Ex4pm.Evidence.Replay.Chain
  alias Ex4pm.{EventLog, OCEL, POWL, Refusal, Run, XES}

  @stats_ops ~w(mean median percentile std_deviation standardize dot_product euclidean_distance
                ks_statistic ks_critical_value regression forecast holt_forecast ewma
                trend_classify)a

  @ferroplan_ops ~w(plan plan_production hierarchical_plan fond_policy fond_policy_validate
                    fond_validate explain hddl_solve readiness version)a

  @doc "Verifies the canonical contract artifacts (ontology, SHACL, WIT, receipt schema)."
  @spec contracts() :: {:ok, map()} | {:error, term()}
  def contracts, do: Ex4pm.Contracts.verify()

  @doc """
  Normalizes raw OCEL v2 JSON into an `Ex4pm.EventLog`.

  Options: `:project?` (default `false`) additionally projects the dataset.
  Refusals: whatever `Ex4pm.OCEL.normalize/1` returns for malformed input.
  """
  @spec ingest(term(), keyword()) :: {:ok, EventLog.t()} | {:error, term()}
  def ingest(raw, opts \\ []) do
    with {:ok, log} <- OCEL.normalize(raw),
         {:ok, projections} <- maybe_project_dataset(log, opts) do
      {:ok, %{log | metadata: Map.put(log.metadata, :projections, projections)}}
    end
  end

  @doc """
  Parses XES XML into an `Ex4pm.EventLog`.

  Options: `:case_object_type`, `:project?` (default `false`).
  Refusals: whatever `Ex4pm.XES.parse/2` returns for malformed input.
  """
  @spec ingest_xes(binary(), keyword()) :: {:ok, EventLog.t()} | {:error, term()}
  def ingest_xes(xml, opts \\ []) do
    with {:ok, log} <- XES.parse(xml, opts),
         {:ok, projections} <- maybe_project_dataset(log, opts) do
      {:ok, %{log | metadata: Map.put(log.metadata, :projections, projections)}}
    end
  end

  @doc """
  Discovers a process model from a log (raw OCEL map or `Ex4pm.EventLog`).

  Default engine: evidence-ranked; `:beam` unless a wasm transport is explicit.
  Options: `:engine`, `:object_type`, `:prefer_wasm`, `:discover_wasm_fun`, plus the
  common options in the module doc. Returns `{:ok, %Ex4pm.Run{}}`; refusals include
  `:no_available_engine`, `:engine_blocked`, `:unknown_engine`.
  """
  @spec discover(EventLog.t() | term(), keyword()) :: run_result()
  def discover(subject, opts \\ []) do
    with {:ok, log} <- ensure_log(subject),
         {:ok, engine_result} <- Engine.execute(:discover, log, opts) do
      receipted_run(:discover, log.subject.hash, engine_result, opts)
    end
  end

  @doc """
  Conformance of a log against a model.

  Default engine `:beam`; `:conform_wasm_fun`/`:prefer_wasm` opt into `:wasm_conform`.
  Options and refusals as `discover/2`.
  """
  @spec conform(EventLog.t() | term(), term(), keyword()) :: run_result()
  def conform(subject, model, opts \\ []) do
    with {:ok, log} <- ensure_log(subject),
         {:ok, engine_result} <- Engine.execute(:conform, {log, model}, opts) do
      receipted_run(:conform, log.subject.hash, engine_result, opts)
    end
  end

  @doc """
  Simulates a model.

  Default engine `:beam`; `:simulate_wasm_fun`/`:prefer_wasm` opt into `:wasm_simulate`.
  Options and refusals as `discover/2`.
  """
  @spec simulate(term(), keyword()) :: run_result()
  def simulate(model, opts \\ []) do
    with {:ok, engine_result} <- Engine.execute(:simulate, model, opts) do
      receipted_run(:simulate, Ex4pm.Core.Hash.digest(model), engine_result, opts)
    end
  end

  @doc """
  Optimizes a model against a log, producing intervention candidates.

  Default engine `:beam`; `:optimize_wasm_fun`/`:prefer_wasm` opt into `:wasm_optimize`.
  Options and refusals as `discover/2`.
  """
  @spec optimize(EventLog.t() | term(), term(), keyword()) :: run_result()
  def optimize(subject, model, opts \\ []) do
    with {:ok, log} <- ensure_log(subject),
         {:ok, engine_result} <- Engine.execute(:optimize, {log, model}, opts) do
      receipted_run(:optimize, log.subject.hash, engine_result, opts)
    end
  end

  @doc """
  Analytical planning (CONSTRUCT only; no DO authority).

  Routing (first match wins):

  | condition | engine | operation |
  |---|---|---|
  | `engine: :ferroplan` | `:ferroplan` | PDDL `plan` (problem needs binary `domain` + `problem`) |
  | `engine: :wasm_strips_plan` | wasm STRIPS planner | `:strips_plan` |
  | `engine: :wasm_htn_plan` | wasm HTN planner | `:htn_plan` |
  | no `:engine`, no `:ex4pm_plan_fun`, problem carries PDDL/HDDL text keys `domain` + `problem` | `:ferroplan` | PDDL `plan` |
  | otherwise | `:ex4pm_plan` | `:plan` (requires `:ex4pm_plan_fun`) |

  Options: `:engine`, `:ex4pm_plan_fun`, `:ferroplan_artifact`,
  `:ferroplan_expected_sha256`, `:strips_plan_wasm_fun`, `:htn_plan_wasm_fun`.
  Refusals: `:invalid_planning_problem` (non-map problem), `:ferroplan_bad_input`,
  `:ferroplan_digest_mismatch`, `:engine_blocked`, `:unsupported_engine_operation`.
  """
  @spec plan(map() | term(), keyword()) :: run_result()
  def plan(problem, opts \\ [])

  def plan(problem, opts) when is_map(problem) do
    {operation, opts} = plan_route(problem, opts)

    with {:ok, engine_result} <- Engine.execute(operation, problem, opts) do
      receipted_run(operation, Ex4pm.Core.Hash.digest(problem), engine_result, opts)
    end
  end

  def plan(other, _opts) do
    {:error,
     Refusal.new(:invalid_planning_problem, "plan requires an admitted planning problem map",
       subject: other
     )}
  end

  @doc """
  Computes a BCINR CMCA consequence allocation through the pinned wasm4pm bridge.

  This is an analytical CONSTRUCT-only path. The result has no ambient SELECT or DO
  authority; consequential execution remains exclusive to `operate/3` and BRCE.

  Default engine: `:cmca_wasm` (needs `:cmca_wasm_fun`). Refusal:
  `:invalid_cmca_problem` for a non-map problem, plus engine refusals.
  """
  @spec cmca(map() | term(), keyword()) :: run_result()
  def cmca(problem, opts \\ [])

  def cmca(problem, opts) when is_map(problem) do
    opts = Keyword.put_new(opts, :engine, :cmca_wasm)

    with {:ok, engine_result} <- Engine.execute(:cmca, problem, opts) do
      receipted_run(:cmca, Ex4pm.Core.Hash.digest(problem), engine_result, opts)
    end
  end

  def cmca(other, _opts) do
    {:error,
     Refusal.new(:invalid_cmca_problem, "cmca requires an admitted consequence-allocation map",
       subject: other
     )}
  end

  @doc """
  Runs a ferroplan operation as a receipted CONSTRUCT run (admitted wasm artifact,
  digest-pinned; see `Ex4pm.Engine.Ferroplan`).

  `op` is one of:

  | op | subject |
  |---|---|
  | `:plan`, `:plan_production` | `%{domain: pddl, problem: pddl, limits: map, extra: map}` |
  | `:hddl_solve` | `%{domain: hddl, problem: hddl, limits: map}` |
  | `:hierarchical_plan`, `:fond_policy` | `%{problem: planning_problem_json_or_map, limits: map}` |
  | `:fond_policy_validate`, `:fond_validate` | `%{problem: ..., plan: universal_plan_map}` |
  | `:explain` | `%{domain: pddl, problem: pddl, plan: plan_map}` |
  | `:readiness`, `:version` | ignored (default `%{}`) |

  Options: `:ferroplan_artifact`, `:ferroplan_expected_sha256`, `:timeout`, `:store`.
  Returns `{:ok, %Ex4pm.Run{}}` (standing `:alive` after a real wasm call, `:partial_alive`
  for `:plan_production`, which is candidate-only). Refusals: `:ferroplan_unsupported_operation`,
  `:ferroplan_bad_input`, `:ferroplan_engine_error`, and `:engine_blocked` when the artifact is
  absent, unpinned or its digest differs from the pin (registry-level admission).
  """
  @spec ferroplan(atom(), map(), keyword()) :: run_result()
  def ferroplan(op, subject \\ %{}, opts \\ [])

  def ferroplan(op, subject, opts) when op in @ferroplan_ops and is_map(subject) do
    operation = :"ferroplan_#{op}"
    opts = Keyword.put(opts, :engine, :ferroplan)

    with {:ok, engine_result} <- Engine.execute(operation, subject, opts) do
      receipted_run(operation, Ex4pm.Core.Hash.digest(subject), engine_result, opts)
    end
  end

  def ferroplan(op, subject, _opts) when op in @ferroplan_ops do
    {:error,
     Refusal.new(:ferroplan_bad_input, "ferroplan #{op} requires a map subject", subject: subject)}
  end

  def ferroplan(op, _subject, _opts) do
    {:error,
     Refusal.new(:ferroplan_unsupported_operation, "ferroplan does not support this operation",
       details: %{operation: op, supported: @ferroplan_ops}
     )}
  end

  @doc """
  Real wasm4pm statistics as a receipted CONSTRUCT run.

  Executes through `Ex4pm.Engine.execute/3` with `engine: :wasm_<op>` (the supervised
  `Ex4pmEngine.Wasm.Host` supplies the transport unless `:<op>_wasm_fun` is given).

  | op | `data` | extra options (default) |
  |---|---|---|
  | `:mean`, `:median`, `:std_deviation` | list of numbers | - |
  | `:percentile` | list of numbers | `:p` (`50.0`) |
  | `:standardize` | list of numeric rows | - |
  | `:dot_product`, `:euclidean_distance` | `{a, b}` | - |
  | `:ks_statistic` | `{sample_a, sample_b}` | - |
  | `:ks_critical_value` | `{n, m}` | `:alpha` (`0.05`) |
  | `:regression` | `{x, y}` | - |
  | `:forecast` | list of numbers | `:alpha` (`0.3`) |
  | `:holt_forecast` | list of numbers | `:alpha` (`0.5`), `:beta` (`0.5`) |
  | `:ewma` | list of numbers | `:alpha` (`0.5`) |
  | `:trend_classify` | list of smoothed numbers | - |

  `data` may instead be the exact request map (atom or string keys) of the wasm export,
  which is passed through unchanged. Refusals: `:unsupported_statistics_operation`,
  `:invalid_statistics_input`, `:engine_blocked`, plus the transport's typed refusals.
  """
  @spec statistics(atom(), term(), keyword()) :: run_result()
  def statistics(op, data, opts \\ [])

  def statistics(op, data, opts) when op in @stats_ops do
    with {:ok, request} <- stats_request(op, data, opts) do
      opts = Keyword.put_new(opts, :engine, :"wasm_#{op}")

      with {:ok, engine_result} <- Engine.execute(op, request, opts) do
        receipted_run(op, Ex4pm.Core.Hash.digest(request), engine_result, opts)
      end
    end
  end

  def statistics(op, _data, _opts) do
    {:error,
     Refusal.new(:unsupported_statistics_operation, "unknown statistics operation",
       details: %{operation: op, supported: @stats_ops}
     )}
  end

  @doc """
  Forecasts a numeric series (convenience over `statistics/3`).

  | option | meaning | default |
  |---|---|---|
  | `:method` | `:forecast` (single exponential), `:holt` (`holt_forecast`), `:ewma` | `:forecast` |
  | `:alpha` | smoothing level | `0.3` (`:forecast`), `0.5` (`:holt`, `:ewma`) |
  | `:beta` | trend smoothing (`:holt` only) | `0.5` |

  Other options (`:store`, `:engine`, ...) pass through to `statistics/3`. Refusals:
  `:invalid_forecast_method` plus those of `statistics/3`.
  """
  @spec forecast([number()], keyword()) :: run_result()
  def forecast(series, opts \\ []) do
    {method, opts} = Keyword.pop(opts, :method, :forecast)

    case method do
      :forecast ->
        statistics(:forecast, series, opts)

      :holt ->
        statistics(:holt_forecast, series, opts)

      :ewma ->
        statistics(:ewma, series, opts)

      other ->
        {:error,
         Refusal.new(
           :invalid_forecast_method,
           "forecast method must be :forecast, :holt or :ewma",
           details: %{method: other}
         )}
    end
  end

  @doc """
  Inspection-only list of the 33 wasm4pm algorithm engines.

  Each entry: `%{id, algorithm, export, standing, reason, executed: false}` where
  `standing` is `:partial_alive` when the engine's transport is available (the
  supervised Host admitted the artifact, or an explicit `:<algo>_wasm_fun` is in `opts`)
  and `:blocked` otherwise. Inspection is not execution; see `health/1` for a probe.
  """
  @spec wasm(keyword()) :: [map()]
  def wasm(opts \\ []) do
    Enum.map(Ex4pmEngine.Wasm.AlgoRegistry.algo_specs(), fn spec ->
      id = :"wasm_#{spec.algorithm_id}"
      module = Enum.find(Engine.Registry.engines(), &(&1.id() == id))
      available = module != nil and module.available?(opts)

      %{
        id: id,
        algorithm: spec.algorithm_id,
        export: spec.export_name,
        standing: if(available, do: :partial_alive, else: :blocked),
        reason: if(available, do: :candidate_available_unexecuted, else: :runtime_unavailable),
        executed: false
      }
    end)
  end

  @doc """
  Per-engine health of the bundled wasm artifacts.

  Returns `%{standing, wasm4pm: map, ferroplan: map}`; each engine map carries
  `artifact_path`, `artifact_present`, `admitted`, `sha256`, `pin_sha256`, `probe`,
  `standing`, (wasm4pm) `source_sha`, `protocol`, `missing_exports`, `refusal`, `host`,
  (ferroplan) `source_version`, `version`.

  Standing: `:blocked` when the artifact is absent or not admitted; `:partial_alive`
  when admitted but not probed; `:alive` when admitted and a real wasm call
  (`mean` for wasm4pm, `version` for ferroplan) executed; `:build_broken` when admitted
  but the probe call failed. The top-level standing is the minimum of the two.

  Options: `:probe` (default `true`), `:artifact_path` (wasm4pm, inspected without Host
  execution), `:ferroplan_artifact`, `:ferroplan_expected_sha256`.
  """
  @spec health(keyword()) :: map()
  def health(opts \\ []) do
    wasm4pm = wasm4pm_health(opts)
    ferroplan = ferroplan_health(opts)

    %{
      standing: Ex4pm.Standing.min(wasm4pm.standing, ferroplan.standing),
      wasm4pm: wasm4pm,
      ferroplan: ferroplan
    }
  end

  @doc """
  Starts the supervised stream pipeline over `events`.

  Options are those of `Ex4pm.Stream.Pipeline.start_link/1`; the sink receives
  observations only and holds no DO authority.
  """
  @spec stream(Enumerable.t(), keyword()) :: term()
  def stream(events, opts) when is_list(opts) do
    Ex4pm.Stream.Pipeline.start_link(Keyword.put(opts, :events, events))
  end

  @doc """
  Operates a POWL model or compiled runtime plan; every task callback crosses BRCE.

  `authority` is the explicit authority map. Refusal: `:invalid_operable_subject`.
  """
  @spec operate(POWL.t() | Ex4pm.Runtime.Plan.t() | term(), term(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def operate(subject, authority, opts \\ [])

  def operate(%POWL{} = model, authority, opts) do
    with {:ok, plan} <- Ex4pm.Runtime.compile(model),
         {:ok, execution} <- Ex4pm.Runtime.execute(plan, authority, opts) do
      {:ok, %{plan: plan, execution: execution, standing: execution.standing}}
    end
  end

  def operate(%Ex4pm.Runtime.Plan{} = plan, authority, opts) do
    with {:ok, execution} <- Ex4pm.Runtime.execute(plan, authority, opts) do
      {:ok, %{plan: plan, execution: execution, standing: execution.standing}}
    end
  end

  def operate(other, _authority, _opts) do
    {:error,
     Refusal.new(:invalid_operable_subject, "operate requires POWL or a compiled runtime plan",
       subject: other
     )}
  end

  @doc """
  Inspection-only candidate engines for `operation` (default `:discover`).

  Each `%Ex4pm.Core.Capability{}` has standing `:partial_alive` (available, unexecuted),
  `:blocked` or `:unsupported`.
  """
  @spec capabilities(atom(), keyword()) :: [Ex4pm.Core.Capability.t()]
  def capabilities(operation \\ :discover, opts \\ []), do: Engine.candidates(operation, opts)

  @doc "Runs `operation` on two engines and compares the results (`Ex4pm.Engine.Differential`)."
  @spec differential(atom(), term(), atom(), atom(), keyword()) :: term()
  def differential(operation, subject, left_engine, right_engine, opts \\ []) do
    Differential.compare(operation, subject, left_engine, right_engine, opts)
  end

  @doc """
  Replays the receipt chain for `hash`.

  Options: `:store`. Refusal: `:receipt_not_found`, plus chain verification refusals.
  """
  @spec replay(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def replay(hash, opts \\ []) when is_binary(hash) do
    store = Keyword.get(opts, :store, Store)

    case Store.get(hash, store) do
      {:ok, receipt} ->
        Chain.verify(receipt, store)

      :error ->
        {:error,
         Refusal.new(:receipt_not_found, "receipt hash is not present in runtime ledger",
           details: %{hash: hash}
         )}
    end
  end

  # -- plan routing ------------------------------------------------------

  defp plan_route(problem, opts) do
    case Keyword.get(opts, :engine) do
      :ferroplan ->
        {:plan, opts}

      engine when engine in [:wasm_strips_plan, :strips_plan] ->
        {:strips_plan, Keyword.put(opts, :engine, :wasm_strips_plan)}

      engine when engine in [:wasm_htn_plan, :htn_plan] ->
        {:htn_plan, Keyword.put(opts, :engine, :wasm_htn_plan)}

      nil ->
        if pddl_text?(problem) and not is_function(opts[:ex4pm_plan_fun]) do
          {:plan, Keyword.put(opts, :engine, :ferroplan)}
        else
          {:plan, Keyword.put(opts, :engine, :ex4pm_plan)}
        end

      _other ->
        {:plan, opts}
    end
  end

  defp pddl_text?(problem) do
    is_binary(Map.get(problem, :domain, Map.get(problem, "domain"))) and
      is_binary(Map.get(problem, :problem, Map.get(problem, "problem")))
  end

  # -- statistics request shaping ---------------------------------------

  defp stats_request(_op, %{} = request, _opts) when not is_struct(request), do: {:ok, request}

  defp stats_request(op, data, opts) do
    case {op, data} do
      {op, d} when op in [:mean, :median, :std_deviation] and is_list(d) ->
        {:ok, %{data: d}}

      {:percentile, d} when is_list(d) ->
        {:ok, %{data: d, p: Keyword.get(opts, :p, 50.0)}}

      {:standardize, d} when is_list(d) ->
        {:ok, %{data: d}}

      {op, {a, b}} when op in [:dot_product, :euclidean_distance] ->
        {:ok, %{a: a, b: b}}

      {:ks_statistic, {a, b}} ->
        {:ok, %{sample_a: a, sample_b: b}}

      {:ks_critical_value, {n, m}} ->
        {:ok, %{n: n, m: m, alpha: Keyword.get(opts, :alpha, 0.05)}}

      {:regression, {x, y}} ->
        {:ok, %{x: x, y: y}}

      {:forecast, d} when is_list(d) ->
        {:ok, %{data: d, alpha: Keyword.get(opts, :alpha, 0.3)}}

      {:holt_forecast, d} when is_list(d) ->
        {:ok,
         %{series: d, alpha: Keyword.get(opts, :alpha, 0.5), beta: Keyword.get(opts, :beta, 0.5)}}

      {:ewma, d} when is_list(d) ->
        {:ok, %{values: d, alpha: Keyword.get(opts, :alpha, 0.5)}}

      {:trend_classify, d} when is_list(d) ->
        {:ok, %{smoothed: d}}

      _ ->
        {:error,
         Refusal.new(:invalid_statistics_input, "data has the wrong shape for #{op}",
           details: %{operation: op, subject: inspect(data, limit: 5)}
         )}
    end
  end

  # -- health -----------------------------------------------------------

  defp wasm4pm_health(opts) do
    alias Ex4pmEngine.Wasm.{Adapter, Admission, Host}

    pin = Admission.manifest_sha256()
    host = host_status()
    custom? = Keyword.has_key?(opts, :artifact_path)

    path =
      Keyword.get(opts, :artifact_path) || (host && host.artifact_path) || Host.artifact_path()

    present = File.regular?(path)
    use_host? = host != nil and not custom? and host.artifact_path == path

    {admitted, refusal} =
      cond do
        not present ->
          {false,
           Refusal.new(:wasm_artifact_missing, "wasm4pm artifact is not present",
             details: %{path: path}
           )}

        use_host? ->
          {host.admitted, host.refusal}

        true ->
          case Admission.admit(File.read!(path), expected_sha256: pin) do
            {:ok, _} -> {true, nil}
            {:error, %Refusal{} = r} -> {false, r}
          end
      end

    probe =
      cond do
        not admitted -> :skipped
        not (use_host? and Keyword.get(opts, :probe, true)) -> :skipped
        true -> probe_wasm4pm()
      end

    %{
      artifact_path: path,
      artifact_present: present,
      admitted: admitted,
      sha256: if(present, do: file_sha256(path)),
      pin_sha256: pin,
      source_sha: Adapter.wasm4pm_source_sha(),
      protocol: Adapter.protocol(),
      missing_exports: missing_exports(refusal),
      refusal: refusal && refusal.code,
      host: host && %{alive: host.alive, restarts: host.restarts},
      probe: probe,
      standing: health_standing(admitted, probe)
    }
  end

  defp ferroplan_health(opts) do
    alias Ex4pm.Engine.Ferroplan, as: Fp

    path = Fp.artifact_path(opts)
    present = Fp.wasm_built?(opts)
    admitted = Fp.available?(opts)

    manifest =
      with {:ok, text} <- File.read(Path.join(Path.dirname(path), "MANIFEST.json")),
           {:ok, %{} = m} <- Jason.decode(text) do
        m
      else
        _ -> %{}
      end

    {probe, version} =
      cond do
        not admitted ->
          {:skipped, nil}

        not Keyword.get(opts, :probe, true) ->
          {:skipped, nil}

        true ->
          case Fp.version(opts) do
            {:ok, %{} = v} -> {:ok, v["version"]}
            {:error, %Refusal{} = r} -> {{:error, r.code}, nil}
            {:error, other} -> {{:error, inspect(other)}, nil}
          end
      end

    %{
      artifact_path: path,
      artifact_present: present,
      admitted: admitted,
      sha256: if(present, do: file_sha256(path)),
      pin_sha256: get_in(manifest, ["artifact", "sha256"]),
      source_version: get_in(manifest, ["source", "version"]),
      version: version,
      probe: probe,
      standing: health_standing(admitted, probe)
    }
  end

  defp health_standing(false, _probe), do: :blocked
  defp health_standing(true, :skipped), do: :partial_alive
  defp health_standing(true, :ok), do: :alive
  defp health_standing(true, _failed), do: :build_broken

  defp probe_wasm4pm do
    case Engine.execute(:mean, %{data: [1.0, 2.0, 3.0]}, engine: :wasm_mean) do
      {:ok, %Ex4pm.Engine.Result{standing: standing}} when standing in [:alive, :partial_alive] ->
        :ok

      {:ok, _} ->
        {:error, :unexpected_standing}

      {:error, %Refusal{code: code}} ->
        {:error, code}

      {:error, other} ->
        {:error, inspect(other)}
    end
  end

  defp host_status do
    Ex4pmEngine.Wasm.Host.status()
  catch
    :exit, _ -> nil
  end

  defp missing_exports(%Refusal{code: :wasm_missing_export, details: %{missing: missing}}),
    do: missing

  defp missing_exports(_), do: []

  defp file_sha256(path) do
    case File.read(path) do
      {:ok, bytes} -> :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
      _ -> nil
    end
  end

  defp receipted_run(operation, subject_hash, engine_result, opts) do
    store = Keyword.get(opts, :store, Store)

    pending =
      Receipt.pending(subject_hash, {:analysis, operation}, nil, %{
        engine: engine_result.engine,
        algorithm: engine_result.algorithm,
        engine_evidence: engine_result.evidence
      })

    with {:ok, _} <- Store.put(pending, store) do
      outcome =
        Receipt.outcome(pending, engine_result.value, engine_result.standing, %{
          engine: engine_result.engine,
          algorithm: engine_result.algorithm,
          engine_evidence: engine_result.evidence
        })

      with {:ok, _} <- Store.put(outcome, store),
           {:ok, projections} <- maybe_project_run(operation, engine_result, outcome, opts) do
        {:ok,
         %Run{
           operation: operation,
           subject_hash: subject_hash,
           standing: engine_result.standing,
           value: engine_result.value,
           receipt: outcome,
           pending: pending,
           engine_result: engine_result,
           projections: projections
         }}
      end
    end
  end

  defp maybe_project_dataset(log, opts) do
    if Keyword.get(opts, :project?, false) do
      case Projector.dataset(log) do
        {:ok, projection} -> {:ok, [projection]}
        error -> error
      end
    else
      {:ok, []}
    end
  end

  defp maybe_project_run(operation, engine_result, receipt, opts) do
    if Keyword.get(opts, :project?, false) do
      with {:ok, receipt_projection} <- Projector.receipt(receipt) do
        case operation do
          :discover ->
            with {:ok, model_projection} <- Projector.process_model(engine_result) do
              {:ok, [model_projection, receipt_projection]}
            end

          :optimize ->
            candidates = Map.get(engine_result.value, :candidates, [])

            candidates
            |> Enum.reduce_while({:ok, [receipt_projection]}, fn candidate, {:ok, acc} ->
              case Projector.intervention(engine_result.subject_hash, candidate) do
                {:ok, projection} -> {:cont, {:ok, [projection | acc]}}
                error -> {:halt, error}
              end
            end)
            |> case do
              {:ok, projections} -> {:ok, Enum.reverse(projections)}
              error -> error
            end

          _ ->
            {:ok, [receipt_projection]}
        end
      end
    else
      {:ok, []}
    end
  end

  defp ensure_log(%EventLog{} = log), do: {:ok, log}
  defp ensure_log(raw), do: OCEL.normalize(raw)
end
