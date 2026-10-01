defmodule Ex4pm.Develop.Semantic.SccCondensation do
  @moduledoc false
  def condense(components, edges) do
    index = components |> Enum.with_index() |> Enum.reduce(%{}, fn {members,i}, acc -> Enum.reduce(members, acc, &Map.put(&2,&1,i)) end)
    edges
    |> Enum.map(fn {a,b} -> {Map.fetch!(index,a), Map.fetch!(index,b)} end)
    |> Enum.reject(fn {a,b} -> a == b end)
    |> MapSet.new()
  end
end
