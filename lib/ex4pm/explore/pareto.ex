defmodule Ex4pm.Explore.Pareto do
  @moduledoc false
  def frontier(items, score_fun) do
    Enum.reject(items, fn item ->
      s = score_fun.(item)
      Enum.any?(items, fn other -> other != item and dominates?(score_fun.(other), s) end)
    end)
  end

  def dominates?(a, b) when map_size(a) == map_size(b) do
    keys = Map.keys(a)
    Enum.all?(keys, &(Map.fetch!(a, &1) >= Map.fetch!(b, &1))) and
      Enum.any?(keys, &(Map.fetch!(a, &1) > Map.fetch!(b, &1)))
  end
end
