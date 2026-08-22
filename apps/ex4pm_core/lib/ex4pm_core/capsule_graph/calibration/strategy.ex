defmodule Ex4pmCore.CapsuleGraph.Calibration.Strategy do
  @moduledoc false

  @strategies [:uniform_cluster, :calibrated_log_odds, :minimax_under_support]

  @spec evaluate(atom(), [number()], [non_neg_integer()]) :: {:ok, number()} | {:error, term()}
  def evaluate(strategy, contributions, supports)
      when strategy in @strategies and is_list(contributions) and is_list(supports) and length(contributions) == length(supports) do
    value =
      case strategy do
        :uniform_cluster -> if contributions == [], do: 0.0, else: Enum.sum(contributions) / length(contributions)
        :calibrated_log_odds -> Enum.sum(contributions)
        :minimax_under_support -> Enum.zip(contributions, supports) |> Enum.map(fn {v, n} -> v * min(n, 8) / 8 end) |> Enum.min(fn -> 0.0 end)
      end

    {:ok, value}
  end

  def evaluate(_, _, _), do: {:error, {:refused, :invalid_calibration_strategy}}

  def candidates, do: @strategies
end
