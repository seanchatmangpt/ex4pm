defmodule Ex4pm.Develop.Evidence.CircuitBreaker do
  def next(:closed, failures, threshold) when failures >= threshold, do: :open
  def next(:open, :probe_success, _threshold), do: :half_open
  def next(:half_open, :success, _threshold), do: :closed
  def next(:half_open, :failure, _threshold), do: :open
  def next(state, _event, _threshold), do: state
end
