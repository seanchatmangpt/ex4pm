defmodule Ex4pm.Explore.Pareto do
  @moduledoc false

  # frontier/2 with a score function: items are compared by the map it returns (all keys maximised).
  def frontier(items, score_fun) when is_function(score_fun, 1) do
    Enum.reject(items, fn item ->
      s = score_fun.(item)
      Enum.any?(items, fn other -> other != item and dominates?(score_fun.(other), s) end)
    end)
  end

  # frontier/2 with an objectives keyword/list of {key, :max | :min}: items are maps.
  def frontier(items, objectives) when is_list(items) and is_list(objectives) do
    Enum.reject(items, fn item ->
      Enum.any?(items, &(&1 != item and dominates?(&1, item, objectives)))
    end)
  end

  def dominates?(a, b) when map_size(a) == map_size(b) do
    keys = Map.keys(a)

    Enum.all?(keys, &(Map.fetch!(a, &1) >= Map.fetch!(b, &1))) and
      Enum.any?(keys, &(Map.fetch!(a, &1) > Map.fetch!(b, &1)))
  end

  def dominates?(a, b, objectives) do
    comparisons =
      Enum.map(objectives, fn {key, direction} ->
        compare(Map.fetch!(a, key), Map.fetch!(b, key), direction)
      end)

    Enum.all?(comparisons, &(&1 in [:better, :equal])) and Enum.any?(comparisons, &(&1 == :better))
  end

  defp compare(a, b, :max) when a > b, do: :better
  defp compare(a, b, :min) when a < b, do: :better
  defp compare(a, b, _) when a == b, do: :equal
  defp compare(_, _, _), do: :worse
end
