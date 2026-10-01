defmodule Ex4pm.Explore.Hypergraph do
  @moduledoc false

  def closure(seed, edges) do
    initial = MapSet.new(seed)
    expand(initial, edges)
  end

  defp expand(reached, edges) do
    next =
      Enum.reduce(edges, reached, fn %{from: from, to: to}, acc ->
        if MapSet.subset?(MapSet.new(from), acc), do: MapSet.union(acc, MapSet.new(to)), else: acc
      end)

    if MapSet.equal?(next, reached), do: reached, else: expand(next, edges)
  end
end
