defmodule Ex4pmEngine.Reactors.WasmCapabilitiesReactor.BootWasm do
  @moduledoc "Reactor step: boots ONE real Wasmex instance from the compiled wasm4pm-ex4pm-bindings artifact, shared by every RunAlgorithm step."
  use Reactor.Step

  alias Ex4pmEngine.Wasm.RealTransport

  @impl true
  def run(%{artifact_path: path}, _context, _options) do
    RealTransport.start(path)
  end
end

defmodule Ex4pmEngine.Reactors.WasmCapabilitiesReactor.RunAlgorithm do
  @moduledoc """
  Reactor step: triggers ONE real wasm4pm-ex4pm-bindings algorithm against
  the shared Wasmex instance `Ex4pmEngine.Reactors.WasmCapabilitiesReactor.BootWasm`
  booted, via the real `Ex4pmEngine.Wasm.RealTransport.default_transport/2`
  -- no fixture closure, real WASM execution and real replay verification on
  every invocation.

  Arguments: `:algo` -- one entry from `Ex4pmEngine.Wasm.RealTransport.algo_specs/0`,
  passed as a literal Reactor `value/1` argument (fixed per step at DSL
  compile time, one `:run_<algo>` step per registry entry).

  Always returns `{:ok, %{standing:, ...}}`, never `{:error, _}` -- a real
  execution failure for THIS algorithm is reported as a `:blocked`/
  `:unsupported` standing in the returned map, not as a step failure, so one
  algorithm's real defect never aborts the other 18 independent steps or
  triggers Reactor's own undo/compensate machinery for work that has
  nothing to compensate (every algorithm here is read-only: `authority:
  :construct_only`, `actuation_performed: false`, per
  `Ex4pmEngine.Wasm.Adapter.accept/4`'s own evidence map).
  """
  use Reactor.Step

  alias Ex4pmEngine.Wasm.{Adapter, RealTransport}

  @impl true
  def run(%{instance: instance, requests: requests, algo: algo}, _context, _options) do
    case Map.fetch(requests, algo.algorithm_id) do
      {:ok, request} ->
        transport =
          RealTransport.default_transport(instance, %{
            export_name: algo.export_name,
            replay_export_name: algo.replay_export_name,
            algorithm_id: algo.algorithm_id,
            protocol: Adapter.protocol(),
            wasm4pm_source_sha: Adapter.wasm4pm_source_sha()
          })

        transport_key = :"#{algo.algorithm_id}_wasm_fun"

        case algo.module.execute(algo.algorithm_id, request, [{transport_key, transport}]) do
          {:ok, %Ex4pm.Engine.Result{} = result} ->
            {:ok, %{standing: result.standing, value: result.value, evidence: result.evidence}}

          {:error, refusal} ->
            {:ok, %{standing: :blocked, reason: refusal}}
        end

      :error ->
        {:ok, %{standing: :unsupported, reason: :no_request_given}}
    end
  end
end

defmodule Ex4pmEngine.Reactors.WasmCapabilitiesReactor do
  @moduledoc """
  Triggers all 19 real `wasm4pm-ex4pm-bindings` process-intelligence
  algorithms as Reactor steps against ONE shared, real Wasmex instance --
  the "wasm4pm capabilities triggered by reactors" requirement.

  Every `:run_<algo>` step is independent of every other `:run_<algo>` step
  (each only depends on `:boot_wasm`), so Reactor schedules them
  concurrently on its own, per this codebase's existing convention
  (`docs/REACTOR_INFORMATION_PLANE.md`: independent observations are
  scheduled concurrently by Reactor rather than with manual concurrency).

  ## Inputs

    * `:artifact_path` -- path to the compiled `wasm4pm_ex4pm_bindings.wasm`.
    * `:requests` -- a map of `%{<algorithm_id> => request_map}`. An
      algorithm with no matching key is reported as `:unsupported` in the
      final results rather than crashing the whole run.

  ## Output (`:final`)

  `%{results: %{<algorithm_id> => %{standing:, value:/reason:, ...}},
    standing: :alive | :partial_alive | :blocked | :build_broken |
    :unsupported}` -- `standing` is the real fold (`Ex4pm.Standing.min/2`,
  the same ALIVE > PARTIAL_ALIVE > BLOCKED > BUILD_BROKEN >
  UNSUPPORTED/UNKNOWN lattice `apps/ex4pm_qualification`'s Crown/Verifier
  already use) across every algorithm -- never a free-text verdict.
  """
  use Reactor

  alias Ex4pmEngine.Wasm.RealTransport

  input(:artifact_path)
  input(:requests)

  step :boot_wasm, Ex4pmEngine.Reactors.WasmCapabilitiesReactor.BootWasm do
    argument(:artifact_path, input(:artifact_path))
  end

  for algo <- RealTransport.algo_specs() do
    step :"run_#{algo.algorithm_id}", Ex4pmEngine.Reactors.WasmCapabilitiesReactor.RunAlgorithm do
      argument(:instance, result(:boot_wasm))
      argument(:requests, input(:requests))
      argument(:algo, value(algo))
      max_retries(0)
    end
  end

  step :final do
    for algo <- RealTransport.algo_specs() do
      argument(algo.algorithm_id, result(:"run_#{algo.algorithm_id}"))
    end

    run(fn results_by_algo, _context ->
      standings = results_by_algo |> Map.values() |> Enum.map(&Map.fetch!(&1, :standing))
      overall = Enum.reduce(standings, :alive, &Ex4pm.Standing.min/2)

      {:ok, %{results: results_by_algo, standing: overall}}
    end)
  end

  return(:final)
end
