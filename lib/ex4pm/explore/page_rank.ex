defmodule Ex4pm.Explore.PageRank do
  @moduledoc false
  def rank(nodes, edges, iterations \\ 20, damping \\ 0.85) when iterations >= 0 do
    n = max(length(nodes), 1)
    initial = Map.new(nodes, &{&1, 1.0 / n})
    iterate(initial, nodes, edges, iterations, damping)
  end

  defp iterate(scores, _nodes, _edges, 0, _d), do: scores
  defp iterate(scores, nodes, edges, remaining, d) do
    iterate(step(nodes, edges, scores, d), nodes, edges, remaining - 1, d)
  end

  defp step(nodes, edges, scores, d) do
    n = max(length(nodes), 1)
    Map.new(nodes, fn node ->
      incoming = for {from, ^node} <- edges, do: from
      contribution = Enum.reduce(incoming, 0.0, fn from, acc ->
        out = Enum.count(edges, &(elem(&1, 0) == from))
        acc + Map.get(scores, from, 0.0) / max(out, 1)
      end)
      {node, (1.0 - d) / n + d * contribution}
    end)
  end
end
