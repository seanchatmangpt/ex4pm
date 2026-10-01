defmodule Ex4pm.Develop.Planner.DominanceFilter do
  @moduledoc false
  def frontier(candidates) do
    Enum.reject(candidates, fn c ->
      Enum.any?(candidates, fn other -> other != c and dominates?(other, c) end)
    end)
  end
  defp dominates?(a, b) do
    av = {a.cost, a.risk, -a.coverage}
    bv = {b.cost, b.risk, -b.coverage}
    elem(av,0) <= elem(bv,0) and elem(av,1) <= elem(bv,1) and elem(av,2) <= elem(bv,2) and av != bv
  end
end
