defmodule Ex4pmCore.CapsuleGraph.Currentness.FixedPoint do
  @moduledoc false

  def close(initial, step, limit \\ 64)
      when is_map(initial) and is_function(step, 1) and is_integer(limit) and limit > 0 do
    iterate(initial, step, limit)
  end

  defp iterate(state, _step, 0), do: {:error, {:refused, :non_convergent_fixed_point, state}}

  defp iterate(state, step, remaining) do
    next = step.(state)
    if next == state, do: {:ok, state}, else: iterate(next, step, remaining - 1)
  end
end
