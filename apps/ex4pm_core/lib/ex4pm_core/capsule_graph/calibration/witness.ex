defmodule Ex4pmCore.CapsuleGraph.Calibration.Witness do
  @moduledoc false

  @outcomes [:pass, :fail, :pending, :unknown, :unsupported]
  @enforce_keys [:attempt_id, :source_fingerprint, :outcome, :observed_at, :scope]
  defstruct [:attempt_id, :source_fingerprint, :outcome, :observed_at, :scope]

  @spec new(String.t(), String.t(), atom(), DateTime.t(), String.t()) :: {:ok, struct()} | {:error, term()}
  def new(attempt_id, source_fingerprint, outcome, %DateTime{} = observed_at, scope)
      when is_binary(attempt_id) and is_binary(source_fingerprint) and outcome in @outcomes and is_binary(scope) do
    if String.trim(attempt_id) != "" and String.trim(source_fingerprint) != "" and String.trim(scope) != "" do
      {:ok, %__MODULE__{attempt_id: attempt_id, source_fingerprint: source_fingerprint, outcome: outcome, observed_at: observed_at, scope: scope}}
    else
      {:error, {:refused, :invalid_calibration_witness}}
    end
  end

  def new(_, _, _, _, _), do: {:error, {:refused, :invalid_calibration_witness}}
end
