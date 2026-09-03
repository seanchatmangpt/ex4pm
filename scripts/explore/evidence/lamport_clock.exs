defmodule Explore.Lamport do
  def tick(c), do: c + 1
  def merge(local, remote), do: max(local, remote) + 1
end
1 = Explore.Lamport.tick(0)
6 = Explore.Lamport.merge(2,5)
3 = Explore.Lamport.merge(2,2)
IO.inspect(%{candidate: :lamport_clock, standing: :alive, causality: :monotone})
