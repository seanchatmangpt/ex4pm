defmodule Ex4pm.Explore.SCC do
  @moduledoc false
  def components(nodes, edges) do
    Enum.reduce(nodes, [], fn node, acc ->
      if Enum.any?(acc, &MapSet.member?(&1, node)) do
        acc
      else
        forward = reachable(node, edges)
        reverse = reachable(node, Enum.map(edges, fn {a, b} -> {b, a} end))
        [MapSet.intersection(forward, reverse) | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp reachable(start, edges), do: walk([start], edges, MapSet.new())
  defp walk([], _edges, seen), do: seen
  defp walk([n | rest], edges, seen) do
    if MapSet.member?(seen, n) do
      walk(rest, edges, seen)
    else
      next = for {^n, b} <- edges, do: b
      walk(next ++ rest, edges, MapSet.put(seen, n))
    end
  end
end
