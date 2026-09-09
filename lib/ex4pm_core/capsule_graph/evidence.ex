defmodule Ex4pmCore.CapsuleGraph.Evidence do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.{Standing, Subject}

  @kinds [:compile, :unit, :integration, :e2e, :replay, :artifact]
  @enforce_keys [:subject, :kind, :outcome, :identity]
  defstruct [:subject, :kind, :outcome, :identity]

  def new(%Subject{} = subject, kind, outcome, identity)
      when kind in @kinds and is_binary(identity) and identity != "" do
    if outcome in Standing.outcomes() do
      {:ok, %__MODULE__{subject: subject, kind: kind, outcome: outcome, identity: identity}}
    else
      {:error, {:refused, :invalid_capsule_evidence, {kind, outcome, identity}}}
    end
  end

  def new(_, kind, outcome, identity),
    do: {:error, {:refused, :invalid_capsule_evidence, {kind, outcome, identity}}}

  def standing(evidence) when is_list(evidence),
    do: Standing.from_outcomes(Enum.map(evidence, & &1.outcome))
end
