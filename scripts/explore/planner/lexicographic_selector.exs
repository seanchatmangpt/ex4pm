defmodule Explore.LexicographicSelector do
  def select(candidates, order) do
    candidates |> Enum.min_by(fn {_id,ctq}->Enum.map(order,&Map.fetch!(ctq,&1)) end) |> elem(0)
  end
end
c=[fast: %{risk: 2,cost: 1}, safe: %{risk: 0,cost: 4}, cheap: %{risk: 1,cost: 0}]
:safe=Explore.LexicographicSelector.select(c,[:risk,:cost])
IO.inspect(%{candidate: :lexicographic_selector, standing: :alive, order: [:risk,:cost]})
