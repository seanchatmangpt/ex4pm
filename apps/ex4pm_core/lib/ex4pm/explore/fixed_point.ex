defmodule Ex4pm.Explore.FixedPoint do
  @moduledoc false
  def converge(value, fun, max_steps \\ 100)
  def converge(value, _fun, 0), do: {:limit, value}
  def converge(value, fun, steps) do
    next = fun.(value)
    if next == value, do: {:ok, value}, else: converge(next, fun, steps - 1)
  end
end
