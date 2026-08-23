defmodule Ex4pmCore.CapsuleGraph.Independence.Witness do
  @moduledoc false

  @outcomes [:pass, :fail, :pending, :unknown, :unsupported]
  @scopes [:focused, :repository, :runtime, :artifact, :dependency, :receipt]
  @enforce_keys [:source_id, :attempt_id, :outcome, :scope, :observed_at]
  defstruct [:source_id, :attempt_id, :outcome, :scope, :observed_at, :evidence_id]

  def new(source_id, attempt_id, outcome, scope, observed_at, evidence_id)
      when is_binary(source_id) and is_binary(attempt_id) and is_binary(evidence_id) do
    cond do
      byte_size(source_id) != 64 -> {:error, {:refused, :invalid_source_id}}
      byte_size(attempt_id) != 64 -> {:error, {:refused, :invalid_attempt_id}}
      outcome not in @outcomes -> {:error, {:refused, :invalid_evidence_outcome}}
      scope not in @scopes -> {:error, {:refused, :invalid_evidence_scope}}
      not match?(%DateTime{}, observed_at) -> {:error, {:refused, :naive_evidence_time}}
      String.trim(evidence_id) == "" -> {:error, {:refused, :missing_evidence_id}}
      true -> {:ok, %__MODULE__{source_id: source_id, attempt_id: attempt_id, outcome: outcome, scope: scope, observed_at: observed_at, evidence_id: evidence_id}}
    end
  end

  def new(_, _, _, _, _, _), do: {:error, {:refused, :invalid_evidence_witness}}
end
