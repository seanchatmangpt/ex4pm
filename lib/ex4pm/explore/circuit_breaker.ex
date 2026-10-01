defmodule Ex4pm.Explore.CircuitBreaker do
  @moduledoc false
  def transition(:closed, {:failure, failures}, threshold) when failures + 1 >= threshold, do: {:open, failures + 1}
  def transition(:closed, {:failure, failures}, _threshold), do: {:closed, failures + 1}
  def transition(:closed, :success, _threshold), do: {:closed, 0}
  def transition(:open, :probe, _threshold), do: {:half_open, 0}
  def transition(:half_open, :success, _threshold), do: {:closed, 0}
  def transition(:half_open, {:failure, failures}, _threshold), do: {:open, failures + 1}
end
