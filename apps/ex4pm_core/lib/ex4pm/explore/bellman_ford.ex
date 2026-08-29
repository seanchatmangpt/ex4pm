defmodule Ex4pm.Explore.BellmanFord do
  @moduledoc false
  def shortest(nodes, edges, source) do
    dist = Map.new(nodes, &{&1, :infinity}) |> Map.put(source, 0)
    dist = relax_rounds(dist, edges, max(length(nodes) - 1, 0))
    if Enum.any?(edges, &improves?(&1, dist)), do: {:error, :negative_cycle}, else: {:ok, dist}
  end

  defp relax_rounds(dist, _edges, 0), do: dist
  defp relax_rounds(dist, edges, rounds) do
    next = Enum.reduce(edges, dist, &relax/2)
    relax_rounds(next, edges, rounds - 1)
  end

  defp relax({u, v, w}, dist) do
    case Map.fetch!(dist, u) do
      :infinity -> dist
      du ->
        alt = du + w
        case Map.fetch!(dist, v) do
          :infinity -> Map.put(dist, v, alt)
          dv when alt < dv -> Map.put(dist, v, alt)
          _ -> dist
        end
    end
  end

  defp improves?({u, v, w}, dist) do
    case {Map.fetch!(dist, u), Map.fetch!(dist, v)} do
      {:infinity, _} -> false
      {_du, :infinity} -> true
      {du, dv} -> du + w < dv
    end
  end
end
