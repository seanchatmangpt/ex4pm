defmodule Ex4pm.Explore.PowlUnfold do
  @moduledoc false

  def unfold(start, next_fun, bound) when is_function(next_fun, 1) and bound >= 0 do
    do_unfold([{start, 0}], next_fun, bound, MapSet.new(), [])
  end

  defp do_unfold([], _next_fun, _bound, _seen, acc), do: Enum.reverse(acc)
  defp do_unfold([{node, depth} | rest], next_fun, bound, seen, acc) do
    key = {node, depth}
    cond do
      depth > bound or MapSet.member?(seen, key) -> do_unfold(rest, next_fun, bound, seen, acc)
      true ->
        children = if depth == bound, do: [], else: Enum.map(next_fun.(node), &{&1, depth + 1})
        do_unfold(rest ++ children, next_fun, bound, MapSet.put(seen, key), [{node, depth} | acc])
    end
  end
end
