defmodule Ex4pm.Explore.WeightedSum do
  @moduledoc false
  def rank(items, weights, score_fun) do
    Enum.sort_by(items, fn item ->
      scores = score_fun.(item)
      -Enum.reduce(weights, 0.0, fn {k, w}, acc -> acc + w * Map.get(scores, k, 0.0) end)
    end)
  end
end
