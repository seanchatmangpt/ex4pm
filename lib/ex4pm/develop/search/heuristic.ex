defmodule Ex4pm.Develop.Search.Heuristic do
  @moduledoc false
  def consistent?(edges, h) do
    Enum.all?(edges, fn {u, v, cost} -> cost >= 0 and h.(u) <= cost + h.(v) end)
  end
end
