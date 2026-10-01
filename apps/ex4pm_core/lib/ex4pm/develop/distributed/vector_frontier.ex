defmodule Ex4pm.Develop.Distributed.VectorFrontier do
  @moduledoc false
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
