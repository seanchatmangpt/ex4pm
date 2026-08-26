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
  alias Ex4pm.Engine.{Beam, CmcaWasm, Ex4pmPlan, Nif, Remote, Wasm}

  alias Ex4pmEngine.Wasm.{
    AllenTemporal,
    Bayesian,
    Conform,
    CtlCheck,
    Discover,
    HtnPlan,
    Markov,
    OcpqEval,
    Optimize,
    PowlMine,
    Simulate,
    StripsPlan,
    Survival
  }

  alias Ex4pm.Refusal

  @engines [
    Discover,
    Conform,
    Simulate,
    Optimize,
    PowlMine,
    Survival,
    Markov,
    Bayesian,
    OcpqEval,
    StripsPlan,
    HtnPlan,
    CtlCheck,
    AllenTemporal,
    Beam,
    Ex4pmPlan,
    CmcaWasm,
    Wasm,
    Nif,
    Remote
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

  # Phase-1 wasm4pm-ex4pm-bindings engines rank above :beam so real WASM
  # execution is preferred once :alive/:partial_alive; :beam remains the
  # evidenced fallback (never deleted pre-emptively — see
  # docs/ARD-v26.9.x.md "Phase-1 wasm4pm bindings").
  defp preference(:wasm_discover), do: 0
  defp preference(:wasm_conform), do: 1
  defp preference(:wasm_simulate), do: 2
  defp preference(:wasm_optimize), do: 3
  defp preference(:wasm_powl_mine), do: 4
  # Phase 2: thin wrappers over already-implemented wasm4pm-workspace
  # algorithms (miniml/ocpq/wasm4pm-cognition) — same ranking discipline.
  defp preference(:wasm_survival), do: 5
  defp preference(:wasm_markov), do: 6
  defp preference(:wasm_bayesian), do: 7
  defp preference(:wasm_ocpq_eval), do: 8
  defp preference(:wasm_strips_plan), do: 9
  defp preference(:wasm_htn_plan), do: 10
  defp preference(:wasm_ctl_check), do: 11
  defp preference(:wasm_allen_temporal), do: 12
  defp preference(:beam), do: 13
  defp preference(:ex4pm_plan), do: 14
  defp preference(:cmca_wasm), do: 15
  defp preference(:wasm), do: 16
  defp preference(:nif), do: 17
  defp preference(:remote), do: 18
  defp preference(_), do: 99

  defp module_for(id), do: Enum.find(@engines, &(&1.id() == id))
  defp reason(false, _available), do: :operation_not_supported
  defp reason(true, false), do: :runtime_unavailable
  defp reason(true, true), do: :candidate_available_unexecuted
end
