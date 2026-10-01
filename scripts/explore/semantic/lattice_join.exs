defmodule Explore.Lattice do
  def join(a,b), do: MapSet.union(a,b)
  def leq?(a,b), do: MapSet.subset?(a,b)
end
a=MapSet.new([:x]); b=MapSet.new([:y]); j=Explore.Lattice.join(a,b)
true=Explore.Lattice.leq?(a,j); true=Explore.Lattice.leq?(b,j)
true=Explore.Lattice.join(a,b)==Explore.Lattice.join(b,a)
IO.inspect(%{candidate: :join_semilattice, standing: :alive})
