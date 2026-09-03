defmodule Ex4pm.Explore.Pareto do
  @moduledoc false

  def frontier(items, objectives) when is_list(items) and is_list(objectives) do
    Enum.reject(items, fn item -> Enum.any?(items, &(&1 != item and dominates?(&1, item, objectives))) end)
  end

  def dominates?(a, b, objectives) do
    comparisons = Enum.map(objectives, fn {key, direction} -> compare(Map.fetch!(a, key), Map.fetch!(b, key), direction) end)
    Enum.all?(comparisons, &(&1 in [:better, :equal])) and Enum.any?(comparisons, &(&1 == :better))
  end

  defp compare(a, b, :max) when a > b, do: :better
  defp compare(a, b, :min) when a < b, do: :better
  defp compare(a, b, _) when a == b, do: :equal
  defp compare(_, _, _), do: :worse
end
