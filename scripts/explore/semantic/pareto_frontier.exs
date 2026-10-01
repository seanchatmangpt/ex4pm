defmodule Explore.Pareto do
  def frontier(points) do
    Enum.reject(points, fn {id,v} -> Enum.any?(points, fn {id2,w} -> id2 != id and dominates?(w,v) end) end)
  end
  defp dominates?(a,b), do: Enum.zip(a,b)|>Enum.all?(fn {x,y}->x<=y end) and Enum.zip(a,b)|>Enum.any?(fn {x,y}->x<y end)
end
f=Explore.Pareto.frontier([a: [1,4], b: [2,2], c: [4,1], d: [3,5]])
true = Keyword.keys(f)==[:a,:b,:c]
IO.inspect(%{candidate: :pareto_frontier, standing: :alive, frontier: f})
