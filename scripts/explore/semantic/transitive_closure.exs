defmodule Explore.TransitiveClosure do
  def closure(nodes, edges) do
    Enum.reduce(nodes, MapSet.new(edges), fn k, acc ->
      Enum.reduce(nodes, acc, fn i, acc2 ->
        Enum.reduce(nodes, acc2, fn j, acc3 ->
          if MapSet.member?(acc3,{i,k}) and MapSet.member?(acc3,{k,j}), do: MapSet.put(acc3,{i,j}), else: acc3
        end)
      end)
    end)
  end
end
c=Explore.TransitiveClosure.closure([:a,:b,:c],[{:a,:b},{:b,:c}])
true=MapSet.member?(c,{:a,:c})
IO.inspect(%{candidate: :transitive_closure, standing: :alive, edge_count: MapSet.size(c)})
