defmodule Ex4pm.Explore.Lattice do
  @moduledoc false
  def closure(seed, join_fun) do
    Stream.iterate(MapSet.new(seed), fn set ->
      joined = for a <- set, b <- set, into: MapSet.new(), do: join_fun.(a, b)
      MapSet.union(set, joined)
    end)
    |> Enum.reduce_while(nil, fn set, prev -> if set == prev, do: {:halt, set}, else: {:cont, set} end)
  end
end
