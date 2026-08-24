defmodule Ex4pm.Explore.Dijkstra do
  @moduledoc false
  def shortest(nodes, edges, source) do
    dist = Map.new(nodes, &{&1, :infinity}) |> Map.put(source, 0)
    visit(MapSet.new(nodes), edges, dist)
  end

  defp visit(unvisited, _edges, dist) when map_size(unvisited) == 0, do: dist
  defp visit(unvisited, edges, dist) do
    u = Enum.min_by(unvisited, fn n -> rank(Map.fetch!(dist, n)) end)
    du = Map.fetch!(dist, u)
    dist = Enum.reduce(edges, dist, fn
      {^u, v, w}, acc when w >= 0 -> relax(acc, v, du, w)
      _, acc -> acc
    end)
    visit(MapSet.delete(unvisited, u), edges, dist)
  end

  defp relax(dist, _v, :infinity, _w), do: dist
  defp relax(dist, v, du, w) do
    alt = du + w
    case Map.fetch!(dist, v) do
      :infinity -> Map.put(dist, v, alt)
      old when alt < old -> Map.put(dist, v, alt)
      _ -> dist
    end
  end
  defp rank(:infinity), do: 1.0e300
  defp rank(v), do: v
end
