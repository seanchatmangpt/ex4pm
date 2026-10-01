defmodule Ex4pm.Explore.CausalDAG do
  @moduledoc false

  def acyclic?(edges) when is_list(edges) do
    nodes = edges |> Enum.flat_map(fn {a, b} -> [a, b] end) |> Enum.uniq()
    Enum.all?(nodes, fn node -> not reachable?(node, node, edges, MapSet.new(), true) end)
  end

  def ancestors(node, edges) do
    parents = for {parent, ^node} <- edges, do: parent
    Enum.reduce(parents, MapSet.new(parents), fn parent, acc -> MapSet.union(acc, ancestors(parent, edges)) end)
  end

  defp reachable?(_target, _current, _edges, _seen, false), do: false
  defp reachable?(target, current, edges, seen, true) do
    children = for {^current, child} <- edges, do: child
    Enum.any?(children, fn child -> child == target or (not MapSet.member?(seen, child) and reachable?(target, child, edges, MapSet.put(seen, child), true)) end)
  end
end
