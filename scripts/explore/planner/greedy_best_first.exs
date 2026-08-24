defmodule Explore.Greedy do
  def solve(start,goal,edges,h), do: loop([{h.(start),start,[start]}],MapSet.new(),goal,edges,h)
  defp loop([{_,goal,path}|_],_,goal,_,_), do: {:ok,path}
  defp loop([{_,node,path}|rest],seen,goal,edges,h) do
    next=for {^node,to}<-edges, not MapSet.member?(seen,to), do:{h.(to),to,path++[to]}
    loop(Enum.sort(next++rest),MapSet.put(seen,node),goal,edges,h)
  end
end
h=fn :a->2; :b->1; :c->3; :d->0 end
{:ok,[:a,:b,:d]}=Explore.Greedy.solve(:a,:d,[{:a,:b},{:a,:c},{:b,:d},{:c,:d}],h)
IO.inspect(%{candidate: :greedy_best_first, standing: :alive})
