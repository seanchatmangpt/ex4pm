defmodule Ex4pmCore.CapsuleGraph.Independence.IndependenceGraph do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Independence.Relation

  def maximum_clique(clusters, provenance, independent_pairs) when is_list(clusters) do
    clusters
    |> indexed_subsets()
    |> Enum.filter(&clique?(&1, provenance, independent_pairs))
    |> Enum.max_by(&length/1, fn -> [] end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp indexed_subsets(clusters) do
    indexed = Enum.with_index(clusters) |> Enum.map(fn {cluster, index} -> {index, cluster} end)
    Enum.reduce(indexed, [[]], fn item, acc -> acc ++ Enum.map(acc, &[item | &1]) end)
  end

  defp clique?(members, provenance, independent_pairs) do
    pairs(members)
    |> Enum.all?(fn {{_, left}, {_, right}} -> clusters_independent?(left, right, provenance, independent_pairs) end)
  end

  defp clusters_independent?(left, right, provenance, independent_pairs) do
    Enum.all?(left, fn l ->
      Enum.all?(right, fn r -> Relation.classify(l, r, provenance, independent_pairs) == :independent end)
    end)
  end

  defp pairs([]), do: []
  defp pairs([head | tail]), do: Enum.map(tail, &{head, &1}) ++ pairs(tail)
end
