defmodule Explore.Antichain do
  def maximal(items, leq?) do
    Enum.reject(items,fn x->Enum.any?(items,fn y->x!=y and leq?.(x,y) end) end)
  end
end
items=[MapSet.new([:a]),MapSet.new([:a,:b]),MapSet.new([:c])]
m=Explore.Antichain.maximal(items,&MapSet.subset?/2)
true=MapSet.new([:a,:b]) in m; true=MapSet.new([:c]) in m
IO.inspect(%{candidate: :antichain_maxima, standing: :alive, cardinality: length(m)})
