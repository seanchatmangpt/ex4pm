defmodule Ex4pm.Explore.VectorClock do
  @moduledoc false
  def tick(clock, actor) do
    case Map.fetch(clock, actor) do
      :error -> Map.put(clock, actor, 1)
        {:ok, v} -> Map.put(clock, actor, v + 1)
    end
  end
  def merge(a, b), do: Map.merge(a, b, fn _k, x, y -> max(x, y) end)
  def compare(a, b) do
    keys = Map.keys(a) ++ Map.keys(b) |> Enum.uniq()
    le = Enum.all?(keys, &(Map.get(a, &1, 0) <= Map.get(b, &1, 0)))
    ge = Enum.all?(keys, &(Map.get(a, &1, 0) >= Map.get(b, &1, 0)))
    cond do
      le and ge -> :equal
      le -> :before
      ge -> :after
      true -> :concurrent
    end
  end
end
