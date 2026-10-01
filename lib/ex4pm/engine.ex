defmodule Ex4pm.Engine.Result do
  @moduledoc "One bounded engine execution result."
  @enforce_keys [:engine, :operation, :subject_hash, :standing, :value]
  defstruct [:engine, :operation, :algorithm, :subject_hash, :standing, :value, evidence: %{}]

  @type t :: %__MODULE__{
          engine: atom(),
          operation: atom(),
          algorithm: atom() | nil,
          subject_hash: String.t(),
          standing: Ex4pm.Standing.t(),
          value: term(),
          evidence: map()
        }
end

defmodule Ex4pm.Engine do
  @moduledoc "DfCM engine behaviour: implementations are candidates, not ambient authority."

  @callback id() :: atom()
  @callback supports?(atom(), keyword()) :: boolean()
  @callback available?(keyword()) :: boolean()
  @callback execute(atom(), term(), keyword()) ::
              {:ok, Ex4pm.Engine.Result.t()} | {:error, term()}

  alias Ex4pm.Engine.Registry

  def candidates(operation, opts \\ []), do: Registry.candidates(operation, opts)
  def select(operation, opts \\ []), do: Registry.select(operation, opts)

  def execute(operation, subject, opts \\ []) do
    with {:ok, module} <- select(operation, opts) do
      module.execute(operation, subject, opts)
    end
  end
end

defmodule Ex4pm.Engine.Registry do
  @moduledoc "Preserves the lawful engine graph and performs explicit/evidence-ranked selection."

  alias Ex4pm.Core.Capability

  alias Ex4pm.Engine.{
    Beam,
    CmcaWasm,
    Ex4pmPlan,
    Ferroplan,
    Nif,
    Remote,
    Wasm,
    WasmRemote
  }

  alias Ex4pmEngine.Wasm.AlgoRegistry

  alias Ex4pm.Refusal

  # The WASM-backed algorithm engines are derived from the generated
  # Ex4pmEngine.Wasm.AlgoRegistry (ontology ex4pmal:engineRank -> ggen), in
  # ascending rank order; the hand list below holds only the non-algorithm
  # candidates.
  @algo_engines AlgoRegistry.engine_modules()
  @algo_id_ranks Map.new(AlgoRegistry.engine_ranks(), fn {module, rank} -> {module.id(), rank} end)

  @engines @algo_engines ++
             [
               Beam,
               Ex4pmPlan,
               CmcaWasm,
               Wasm,
               Nif,
               Remote,
               WasmRemote,
               # Native ferroplan engine: explicit-only (`engine: :ferroplan`), no ranked
               # preference; falls to the default (99) clause below.
               Ferroplan
             ]

  def engines, do: @engines

  def candidates(operation, opts \\ []) do
    @engines
    |> Enum.map(fn module ->
      supported = module.supports?(operation, opts)
      available = supported and module.available?(opts)

      standing =
        cond do
          not supported -> :unsupported
          available -> :partial_alive
          true -> :blocked
        end

      %Capability{
        id: module.id(),
        kind: :engine,
        standing: standing,
        reason: reason(supported, available),
        evidence: %{module: module, inspected: true, executed: false},
        constraints: %{operation: operation}
      }
    end)
  end

  def select(operation, opts \\ []) do
    explicit = Keyword.get(opts, :engine)
    candidates = candidates(operation, opts)

    case explicit do
      nil ->
        candidates
        |> Enum.filter(&(&1.standing in [:alive, :partial_alive]))
        |> Enum.reject(&beam_colliding_without_opt_in?(&1.id, opts))
        |> Enum.sort_by(fn candidate ->
          {preference(candidate.id), -Ex4pm.Standing.rank(candidate.standing)}
        end)
        |> case do
          [%Capability{id: id} | _] ->
            {:ok, module_for(id)}

          [] ->
            {:error,
             Refusal.new(:no_available_engine, "no available engine supports operation",
               details: %{operation: operation, candidates: candidates}
             )}
        end

      id ->
        case Enum.find(candidates, &(&1.id == id)) do
          nil ->
            {:error,
             Refusal.new(:unknown_engine, "requested engine is not registered",
               details: %{engine: id}
             )}

          %Capability{standing: :unsupported} ->
            {:error,
             Refusal.new(:unsupported_engine_operation, "engine does not support operation",
               details: %{engine: id, operation: operation}
             )}

          %Capability{standing: :blocked} ->
            {:error,
             Refusal.new(:engine_blocked, "engine runtime is unavailable",
               details: %{engine: id, operation: operation}
             )}

          %Capability{id: selected} ->
            {:ok, module_for(selected)}
        end
    end
  end

  # discover/conform/simulate/optimize are also served by the evidenced :beam engine and the
  # wasm result shapes differ. A wasm engine that is available only through the supervised
  # Host fallback therefore does NOT displace :beam in implicit selection; the caller opts in
  # with `prefer_wasm: true`, an explicit `engine:`, or an explicit `<algo>_wasm_fun` transport.
  @beam_colliding_wasm %{
    wasm_discover: :discover_wasm_fun,
    wasm_conform: :conform_wasm_fun,
    wasm_simulate: :simulate_wasm_fun,
    wasm_optimize: :optimize_wasm_fun
  }

  defp beam_colliding_without_opt_in?(id, opts) do
    case Map.fetch(@beam_colliding_wasm, id) do
      {:ok, fun_key} ->
        not (Keyword.get(opts, :prefer_wasm, false) or Keyword.has_key?(opts, fun_key))

      :error ->
        false
    end
  end

  # Algorithm engines (ranks 0..32) rank above :beam so real WASM execution is
  # preferred once :alive/:partial_alive; their ranks come from the generated
  # AlgoRegistry (ontology ex4pmal:engineRank). :beam remains the evidenced
  # fallback (never deleted pre-emptively -- see docs/ARD-v26.9.x.md).
  defp preference(id) when is_map_key(@algo_id_ranks, id), do: Map.fetch!(@algo_id_ranks, id)
  defp preference(:beam), do: 40
  defp preference(:ex4pm_plan), do: 41
  defp preference(:cmca_wasm), do: 42
  defp preference(:wasm), do: 43
  defp preference(:nif), do: 44
  defp preference(:remote), do: 45
  # Additive remote network-backed candidate: not ranked into the implicit-selection preference table yet — only reachable
  # via an explicit `engine: :wasm_remote` opt (as is :ferroplan, documented rank 99). Falls to the default (_ -> 99)
  # clause deliberately; flipping this into the ranked table is Phase 2, out of
  # scope here.
  defp preference(_), do: 99

  defp module_for(id), do: Enum.find(@engines, &(&1.id() == id))
  defp reason(false, _available), do: :operation_not_supported
  defp reason(true, false), do: :runtime_unavailable
  defp reason(true, true), do: :candidate_available_unexecuted
end
