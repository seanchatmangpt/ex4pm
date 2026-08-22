defmodule Ex4pmCore.CapsuleGraph.Calibration.Trial do
  @moduledoc false

  @enforce_keys [:source_id, :truth, :prediction, :observed_at, :id]
  defstruct [:source_id, :truth, :prediction, :observed_at, :id]

  @outcomes [:pass, :fail]

  @spec new(String.t(), atom(), atom(), DateTime.t()) :: {:ok, struct()} | {:error, term()}
  def new(source_id, truth, prediction, %DateTime{} = observed_at)
      when is_binary(source_id) and truth in @outcomes and prediction in @outcomes do
    body = {source_id, truth, prediction, DateTime.to_iso8601(observed_at)}
    id = :crypto.hash(:sha256, :erlang.term_to_binary(body, [:deterministic])) |> Base.encode16(case: :lower)
    {:ok, %__MODULE__{source_id: source_id, truth: truth, prediction: prediction, observed_at: observed_at, id: id}}
  end

  def new(_, _, _, _), do: {:error, {:refused, :invalid_calibration_trial}}
end
