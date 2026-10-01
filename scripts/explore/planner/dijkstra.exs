defmodule Explore.Dijkstra do
  def solve(start, goal, edges), do: loop(%{start => {0,[start]}}, MapSet.new(), goal, edges)
  defp loop(best, seen, goal, edges) do
    {node,{cost,path}} = best |> Enum.reject(fn {n,_}->MapSet.member?(seen,n) end) |> Enum.min_by(fn {_,{c,_}}->c end)
    if node == goal, do: {:ok,cost,path}, else: loop(relax(best,node,cost,path,edges),MapSet.put(seen,node),goal,edges)
  end
  defp relax(best,node,cost,path,edges), do: Enum.reduce(for({^node,to,w}<-edges, do:{to,w}),best,fn {to,w},acc ->
    cand={cost+w,path++[to]}; case Map.get(acc,to) do nil->Map.put(acc,to,cand); {old,_} when cost+w<old->Map.put(acc,to,cand); _->acc end
  end)
end
{:ok,2,[:a,:b,:d]}=Explore.Dijkstra.solve(:a,:d,[{:a,:d,9},{:a,:b,1},{:b,:d,1}])
IO.inspect(%{candidate: :dijkstra, standing: :alive})
