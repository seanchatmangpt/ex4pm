defmodule Ex4pm.Explore.AStar do
  @moduledoc false
  def next(open, g_score, heuristic) do
    Enum.min_by(open, fn node -> Map.get(g_score, node, :infinity) |> total(heuristic.(node)) end, fn -> nil end)
  end

  defp total(:infinity, _h), do: 1.0e300
  defp total(g, h), do: g + h
end
