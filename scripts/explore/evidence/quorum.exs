defmodule Explore.Quorum do
  def majority(n), do: div(n,2)+1
  def admitted?(acks,n), do: MapSet.size(MapSet.new(acks)) >= majority(n)
end
true = Explore.Quorum.admitted?([:a,:b],3)
false = Explore.Quorum.admitted?([:a],3)
false = Explore.Quorum.admitted?([:a,:a],3)
IO.inspect(%{candidate: :majority_quorum, standing: :alive})
