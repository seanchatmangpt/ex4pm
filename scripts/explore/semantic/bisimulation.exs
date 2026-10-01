defmodule Explore.Bisimulation do
  def equivalent?(left,right,transitions) do
    labels=fn s->for {^s,l,_}<-transitions, do:l end
    MapSet.new(labels.(left))==MapSet.new(labels.(right))
  end
end
trans=[{:p,:go,:p1},{:q,:go,:q1},{:r,:stop,:r1}]
true=Explore.Bisimulation.equivalent?(:p,:q,trans)
false=Explore.Bisimulation.equivalent?(:p,:r,trans)
IO.inspect(%{candidate: :bisimulation_observation, standing: :partial_alive, bound: :one_step})
