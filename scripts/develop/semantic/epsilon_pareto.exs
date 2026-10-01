defmodule Ex4pm.Develop.Semantic.EpsilonPareto do
  @moduledoc false
  def frontier(candidates, epsilon) when epsilon >= 0 do
    Enum.reject(candidates, fn c -> Enum.any?(candidates, fn o -> o != c and dominates?(o,c,epsilon) end) end)
  end
  defp dominates?(a,b,e) do
    a.error <= b.error + e and a.cost <= b.cost + e and (a.error < b.error - e or a.cost < b.cost - e)
  end
end
