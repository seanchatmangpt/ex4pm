defmodule Explore.EpsilonDominance do
  def dominates?(a,b,e), do: Enum.zip(a,b)|>Enum.all?(fn {x,y}->x<=y+e end) and Enum.zip(a,b)|>Enum.any?(fn {x,y}->x<y-e end)
end
true = Explore.EpsilonDominance.dominates?([1.0,2.0],[1.2,2.5],0.1)
false = Explore.EpsilonDominance.dominates?([1.15,2.0],[1.2,2.05],0.1)
IO.inspect(%{candidate: :epsilon_dominance, standing: :alive})
