defmodule Ex4pm.Develop.Semantic.TopologyRefusal do
  @moduledoc false
  def acyclic?(nodes, edges) do
    incoming = Enum.reduce(edges, Map.new(nodes, &{&1, 0}), fn {_a,b}, acc -> Map.update(acc,b,1,&(&1+1)) end)
    queue = for {n,0} <- incoming, do: n
    consume(queue, incoming, edges, 0) == length(nodes)
  end
  defp consume([], _incoming, _edges, count), do: count
  defp consume([n|rest], incoming, edges, count) do
    {incoming2, new} = edges |> Enum.filter(fn {a,_} -> a == n end) |> Enum.reduce({incoming,[]}, fn {_a,b},{acc,q} ->
      v = Map.fetch!(acc,b)-1
      {Map.put(acc,b,v), if(v==0, do: [b|q], else: q)}
    end)
    consume(rest ++ Enum.reverse(new), incoming2, edges, count+1)
  end
end
