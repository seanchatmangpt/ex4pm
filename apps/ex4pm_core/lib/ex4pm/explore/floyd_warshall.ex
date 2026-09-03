defmodule Ex4pm.Explore.FloydWarshall do
  @moduledoc false
  def all_pairs(nodes, edges) do
    dist = Enum.reduce(nodes, %{}, fn i, acc -> Map.put(acc, {i, i}, 0) end)
    dist = Enum.reduce(edges, dist, fn {a, b, w}, acc -> Map.update(acc, {a, b}, w, &min(&1, w)) end)
    Enum.reduce(nodes, dist, fn k, dk ->
      Enum.reduce(nodes, dk, fn i, di ->
        Enum.reduce(nodes, di, fn j, acc -> relax(acc, i, j, k) end)
      end)
    end)
  end

  defp relax(dist, i, j, k) do
    with {:ok, ik} <- Map.fetch(dist, {i, k}), {:ok, kj} <- Map.fetch(dist, {k, j}) do
      Map.update(dist, {i, j}, ik + kj, &min(&1, ik + kj))
    else
      _ -> dist
    end
  end
end
