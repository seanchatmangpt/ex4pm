defmodule Ex4pm.Develop.Search.Selector do
  @moduledoc false
  @strategies [:min_cost, :min_expansions, :min_regret, :max_consensus]
  def strategies, do: @strategies
  def choose(candidates, strategy, score) when strategy in @strategies do
    candidates |> Enum.min_by(fn c -> {score.(strategy, c), inspect(c)} end, fn -> nil end)
  end
  def choose(_, _, _), do: {:error, :unknown_strategy}
end
