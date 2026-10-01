defmodule Ex4pm.Explore.WeightedSelector do
  @moduledoc false

  def rank(candidates, weights) when is_list(candidates) and is_map(weights) do
    keys = Map.keys(weights)
    ranges = Map.new(keys, fn key ->
      values = Enum.map(candidates, &Map.fetch!(&1, key))
      {key, {Enum.min(values), Enum.max(values)}}
    end)

    candidates
    |> Enum.map(fn candidate -> {candidate, score(candidate, weights, ranges)} end)
    |> Enum.sort_by(fn {_candidate, score} -> -score end)
  end

  defp score(candidate, weights, ranges) do
    Enum.reduce(weights, 0.0, fn {key, weight}, acc ->
      {min, max} = Map.fetch!(ranges, key)
      value = Map.fetch!(candidate, key)
      normalized = if max == min, do: 1.0, else: (value - min) / (max - min)
      acc + weight * normalized
    end)
  end
end
