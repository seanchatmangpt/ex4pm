defmodule Ex4pmCore.CapsuleGraph.Independence.Provenance do
  @moduledoc false

  def new(edges) when is_list(edges) do
    graph =
      Enum.reduce(edges, %{}, fn {parent, child}, acc ->
        Map.update(acc, parent, [child], &[child | &1])
      end)

    case cycle?(graph) do
      true -> {:error, {:refused, :provenance_cycle}}
      false -> {:ok, graph}
    end
  end

  def new(_), do: {:error, {:refused, :invalid_provenance_graph}}

  def derived?(graph, ancestor, descendant) when is_map(graph) do
    walk(graph, [ancestor], MapSet.new(), descendant)
  end

  defp walk(_, [], _, _), do: false

  defp walk(graph, [node | rest], seen, target) do
    children = Map.get(graph, node, [])

    cond do
      target in children -> true
      MapSet.member?(seen, node) -> walk(graph, rest, seen, target)
      true -> walk(graph, children ++ rest, MapSet.put(seen, node), target)
    end
  end

  defp cycle?(graph) do
    Enum.any?(Map.keys(graph), fn node -> dfs_cycle?(graph, node, MapSet.new(), MapSet.new()) end)
  end

  defp dfs_cycle?(graph, node, visiting, visited) do
    cond do
      MapSet.member?(visiting, node) ->
        true

      MapSet.member?(visited, node) ->
        false

      true ->
        visiting = MapSet.put(visiting, node)
        visited = MapSet.put(visited, node)
        Enum.any?(Map.get(graph, node, []), &dfs_cycle?(graph, &1, visiting, visited))
    end
  end
end
