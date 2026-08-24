defmodule Explore.SCC do
  def components(nodes, edges) do
    reach = fn a,b -> reachable?(a,b,edges,MapSet.new()) end
    nodes |> Enum.reduce([],fn n,acc -> if Enum.any?(acc,&(n in &1)), do: acc, else: [Enum.filter(nodes,fn m->reach.(n,m) and reach.(m,n) end)|acc] end) |> Enum.map(&Enum.sort/1) |> Enum.sort()
  end
  defp reachable?(a,a,_,_), do: true
  defp reachable?(a,b,e,seen) do
    if MapSet.member?(seen,a), do: false, else: Enum.any?(for({^a,x}<-e,do:x), &reachable?(&1,b,e,MapSet.put(seen,a)))
  end
end
comps=Explore.SCC.components([:a,:b,:c],[{:a,:b},{:b,:a},{:b,:c}])
true = comps == [[:a,:b],[:c]]
IO.inspect(%{candidate: :scc_partition, standing: :alive, components: comps})
