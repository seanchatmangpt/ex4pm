defmodule Ex4pm.Explore.Quorum do
  @moduledoc false
  def majority(n) when n > 0, do: div(n, 2) + 1
  def intersects?(n, q1, q2) when n > 0, do: q1 + q2 > n
  def safe_read_write?(n, read_q, write_q), do: intersects?(n, read_q, write_q) and 2 * write_q > n
end
