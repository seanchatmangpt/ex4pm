defmodule Ex4pm.Develop.Planner.RegretBound do
  @moduledoc false
  def maximum(actions) do
    best = actions |> Enum.map(& &1.loss) |> Enum.min()
    actions |> Enum.map(fn a -> {a.id, a.loss - best} end) |> Enum.max_by(&elem(&1, 1))
  end
  def choose(actions), do: actions |> Enum.min_by(fn a -> {a.worst_case - a.best_case, a.id} end)
end
