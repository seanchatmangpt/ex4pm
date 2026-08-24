defmodule Explore.Topo do
  def sort(nodes,edges), do: kahn(nodes,edges,[])
  defp kahn([],_,acc), do: {:ok,Enum.reverse(acc)}
  defp kahn(nodes,edges,acc) do
    roots=Enum.filter(nodes,fn n->not Enum.any?(edges,fn {_,to}->to==n end) end)
    if roots==[], do: {:cycle,Enum.sort(nodes)}, else:
      r=Enum.min(roots); kahn(List.delete(nodes,r),Enum.reject(edges,fn {from,_}->from==r end),[r|acc])
  end
end
{:ok,[:a,:b,:c]}=Explore.Topo.sort([:a,:b,:c],[{:a,:b},{:b,:c}])
{:cycle,[:a,:b]}=Explore.Topo.sort([:a,:b],[{:a,:b},{:b,:a}])
IO.inspect(%{candidate: :topological_sort, standing: :alive, falsifier: :cycle})
