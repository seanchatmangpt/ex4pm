defmodule Ex4pm.Explore.PageRank do
  @moduledoc false
  def rank(nodes, edges, iterations \\ 20, damping \\ 0.85) do
    n = max(length(nodes), 1)
    initial = Map.new(nodes, &{&1, 1.0 / n})
    Enum.reduce(1..max(iterations, 0), initial, fn _, scores -> step(nodes, edges, scores, damping) end)
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
