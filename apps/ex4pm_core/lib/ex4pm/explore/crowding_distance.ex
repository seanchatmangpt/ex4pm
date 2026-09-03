defmodule Ex4pm.Explore.CrowdingDistance do
  @moduledoc false
  def score(points, keys) do
    base = Map.new(points, &{&1, 0.0})
    Enum.reduce(keys, base, fn key, acc -> accumulate(points, key, acc) end)
  end

  defp accumulate(points, key, acc) do
    sorted = Enum.sort_by(points, &Map.fetch!(&1, key))
    case sorted do
      [] -> acc
      [_] -> acc
      _ ->
        minv = Map.fetch!(hd(sorted), key); maxv = Map.fetch!(List.last(sorted), key); span = max(maxv - minv, 1.0e-12)
        acc = acc |> Map.put(hd(sorted), :infinity) |> Map.put(List.last(sorted), :infinity)
        sorted |> Enum.chunk_every(3, 1, :discard) |> Enum.reduce(acc, fn [a, b, c], m ->
          if Map.get(m, b) == :infinity, do: m, else: Map.update!(m, b, &(&1 + (Map.fetch!(c, key) - Map.fetch!(a, key)) / span))
        end)
    end
  end
end
