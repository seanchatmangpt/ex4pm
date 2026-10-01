defmodule Ex4pm.Develop.Search.ParetoPolicy do
  @moduledoc false
  def frontier(candidates, axes) do
    Enum.reject(candidates, fn c -> Enum.any?(candidates, fn other -> other != c and dominates?(other, c, axes) end) end)
  end
  defp dominates?(a, b, axes) do
    av = Enum.map(axes, & &1.(a)); bv = Enum.map(axes, & &1.(b))
    Enum.zip(av, bv) |> Enum.all?(fn {x,y} -> x <= y end) and Enum.zip(av,bv) |> Enum.any?(fn {x,y} -> x < y end)
  end
end
