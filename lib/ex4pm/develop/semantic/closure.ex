defmodule Ex4pm.Develop.Semantic.Closure do
  @moduledoc false
  def close(seed, step, limit) when is_integer(limit) and limit >= 0 do
    Enum.reduce_while(0..limit, MapSet.new(seed), fn _, acc ->
      next = MapSet.union(acc, MapSet.new(step.(acc)))
      if next == acc, do: {:halt, {:ok, acc}}, else: {:cont, next}
    end)
    |> case do
      {:ok, acc} -> {:ok, acc}
      acc -> {:error, {:no_fixed_point_within_bound, acc}}
    end
  end
end
