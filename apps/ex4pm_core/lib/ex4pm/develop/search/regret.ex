defmodule Ex4pm.Develop.Search.Regret do
  @moduledoc false
  def minimax(candidates, losses) do
    best = candidates |> Enum.map(&losses.(&1)) |> Enum.min(fn -> 0 end)
    candidates
    |> Enum.map(fn c -> {c, losses.(c) - best} end)
    |> Enum.min_by(fn {c, regret} -> {regret, inspect(c)} end)
  end
end
