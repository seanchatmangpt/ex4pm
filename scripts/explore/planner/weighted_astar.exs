defmodule Explore.WeightedAStar do
  def priority(g,h,w) when w>=1.0, do: g+w*h
end
5.0=Explore.WeightedAStar.priority(1.0,2.0,2.0)
3.0=Explore.WeightedAStar.priority(1.0,2.0,1.0)
IO.inspect(%{candidate: :weighted_astar, standing: :alive, assumption: :w_ge_1})
