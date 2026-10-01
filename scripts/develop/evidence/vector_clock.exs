defmodule Ex4pm.Develop.Evidence.VectorClock do
  def join(a,b), do: Map.merge(a,b,fn _k,x,y->max(x,y) end)
  def compare(a,b) do
    keys=MapSet.union(MapSet.new(Map.keys(a)),MapSet.new(Map.keys(b)))
    le=Enum.all?(keys,fn k->Map.get(a,k,0)<=Map.get(b,k,0) end)
    ge=Enum.all?(keys,fn k->Map.get(a,k,0)>=Map.get(b,k,0) end)
    cond do le and ge -> :equal; le -> :before; ge -> :after; true -> :concurrent end
  end
end
