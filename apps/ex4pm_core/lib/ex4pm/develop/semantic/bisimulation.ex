defmodule Ex4pm.Develop.Semantic.Bisimulation do
  @moduledoc false
  def witness(left, right, step, depth) when depth >= 0 do
    do_witness([{left, right}], MapSet.new(), step, depth)
  end
  defp do_witness([], seen, _step, _depth), do: {:ok, seen}
  defp do_witness(_queue, _seen, _step, 0), do: {:error, :depth_bound_exhausted}
  defp do_witness([{l, r} | rest], seen, step, depth) do
    pair = {l, r}
    if MapSet.member?(seen, pair) do
      do_witness(rest, seen, step, depth)
    else
      ln = MapSet.new(step.(l)); rn = MapSet.new(step.(r))
      if MapSet.size(ln) != MapSet.size(rn), do: {:error, {:branching_divergence, pair}}, else: do_witness(rest, MapSet.put(seen, pair), step, depth - 1)
    end
  end
end
