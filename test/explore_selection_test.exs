defmodule Ex4pm.Explore.SelectionTest do
  use ExUnit.Case, async: true

  test "Pareto preserves incomparable candidates" do
    items = [:a, :b, :c]
    scores = %{a: %{speed: 3, safety: 1}, b: %{speed: 1, safety: 3}, c: %{speed: 1, safety: 1}}
    assert MapSet.new(Ex4pm.Explore.Pareto.frontier(items, &Map.fetch!(scores, &1))) == MapSet.new([:a, :b])
  end

  test "weighted sum and lexicographic may select different winners" do
    items = [:a, :b]
    scores = %{a: %{speed: 10, safety: 1}, b: %{speed: 4, safety: 6}}
    assert hd(Ex4pm.Explore.WeightedSum.rank(items, %{speed: 1.0, safety: 1.0}, &Map.fetch!(scores, &1))) == :a
    assert hd(Ex4pm.Explore.Lexicographic.rank(items, [:safety, :speed], &Map.fetch!(scores, &1))) == :b
  end
end
