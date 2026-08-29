defmodule Ex4pm.Develop.Distributed.FailureDominance do
  @moduledoc false
  @order %{build_broken: 5, blocked: 4, unknown: 3, partial_alive: 2, alive: 1}
  def worst(states), do: Enum.max_by(states, &Map.get(@order, &1, 99), fn -> :unknown end)
end
