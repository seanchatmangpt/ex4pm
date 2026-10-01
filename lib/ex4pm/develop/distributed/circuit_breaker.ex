defmodule Ex4pm.Develop.Distributed.CircuitBreaker do
  @moduledoc false
  def transition(:closed, {:failure, count}, threshold) when count + 1 >= threshold, do: {:open, count + 1}
  def transition(:closed, {:failure, count}, _threshold), do: {:closed, count + 1}
  def transition(:open, :probe, _threshold), do: {:half_open, 0}
  def transition(:half_open, :success, _threshold), do: {:closed, 0}
  def transition(:half_open, :failure, _threshold), do: {:open, 1}
  def transition(state, _event, _threshold), do: state
end
