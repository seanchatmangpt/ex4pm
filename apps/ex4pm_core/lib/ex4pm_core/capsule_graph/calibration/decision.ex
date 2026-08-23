defmodule Ex4pmCore.CapsuleGraph.Calibration.Decision do
  @moduledoc false

  @enforce_keys [:statistic, :result]
  defstruct [:statistic, :result]

  @spec decide([number()], number(), number()) :: {:ok, struct()} | {:error, term()}
  def decide(values, accept_threshold, reject_threshold)
      when is_list(values) and is_number(accept_threshold) and is_number(reject_threshold) and
             accept_threshold > reject_threshold do
    statistic = Enum.reduce(values, 0.0, &+/2)

    result =
      cond do
        statistic >= accept_threshold -> :accept_bounded
        statistic <= reject_threshold -> :reject
        true -> :continue
      end

    {:ok, %__MODULE__{statistic: statistic, result: result}}
  end

  def decide(_, _, _), do: {:error, {:refused, :invalid_sequential_thresholds}}
end
