defmodule Ex4pm.Explore.FixedPoint do
  @moduledoc false

  def iterate(seed, step, opts \\ []) when is_function(step, 1) do
    max = Keyword.get(opts, :max_iterations, 1_000)
    do_iterate(seed, step, max, 0)
  end

  defp do_iterate(value, _step, max, count) when count >= max,
    do: {:error, {:no_fixed_point, value, count}}

  defp do_iterate(value, step, max, count) do
    next = step.(value)
    if next == value, do: {:ok, value, count}, else: do_iterate(next, step, max, count + 1)
  end
end
