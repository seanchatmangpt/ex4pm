defmodule Ex4pm.Develop.Semantic.TopologyRefusal do
  @moduledoc false
  def sort(nodes, edges) do
    incoming = Enum.reduce(edges, Map.new(nodes,&{&1,0}), fn {_a,b},acc -> Map.update!(acc,b,&(&1+1)) end)
    queue = incoming |> Enum.filter(fn {_n,d}->d==0 end) |> Enum.map(&elem(&1,0)) |> Enum.sort()
    visit(queue, edges, incoming, [])
  end
  defp visit([], _edges, incoming, out) do
    if length(out)==map_size(incoming), do: {:ok, Enum.reverse(out)}, else: {:refused,:cyclic_projection}
  end
  defp visit([n|rest], edges, incoming, out) do
    {incoming2,new} = Enum.reduce(Enum.filter(edges, fn {a,_}->a==n end), {incoming,[]}, fn {_a,b},{acc,q} ->
      acc2=Map.update!(acc,b,&(&1-1)); if acc2[b]==0, do: {acc2,[b|q]}, else: {acc2,q}
    end)
    visit(Enum.sort(rest++new), edges, incoming2, [n|out])
  end
end
