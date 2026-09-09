defmodule Ex4pmCore.CapsuleCurrentnessLatticeTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.Lattice

  test "failure dominates positive local standing" do
    assert :blocked = Lattice.join([:partial_alive, :blocked])
    assert :build_broken = Lattice.join([:alive, :build_broken, :blocked])
    assert :unknown = Lattice.join([:partial_alive, :unknown])
    assert :unknown = Lattice.join([])
  end
end
