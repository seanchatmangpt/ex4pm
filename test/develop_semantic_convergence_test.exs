defmodule Ex4pm.Develop.SemanticConvergenceTest do
  use ExUnit.Case, async: true
  alias Ex4pm.Develop.Semantic.{Closure, ConvergenceCertificate, DivergenceWitness, Law, Monotonicity, TopologyRefusal}

  test "semantic convergence requires law, monotonicity and bounded evidence" do
    assert {:ok, closed} = Closure.close([0], fn set -> Enum.map(set, &min(&1 + 1, 2)) end, 4)
    assert MapSet.equal?(closed, MapSet.new([0,1,2]))
    assert Law.semilattice?([0,1,2], &max/2)
    assert Monotonicity.monotone?([{0,1},{1,2}], &min(&1+1,2), &<=/2)
    assert {:ok, _} = ConvergenceCertificate.certify([3,2,1,1], fn a,b -> abs(a-b) end, 0)
    assert {:diverged_at, 1, 2, 9} = DivergenceWitness.first([1,2],[1,9], & &1)
    assert TopologyRefusal.acyclic?([:a,:b],[{:a,:b}])
  end
end
