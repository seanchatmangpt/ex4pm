defmodule Ex4pm.Develop.DistributedRuntimeTest do
  use ExUnit.Case, async: true
  alias Ex4pm.Develop.Distributed.{CircuitBreaker, ConsistentRing, EffectiveQuorum, FailureDominance, Lease, ReplayChain, TemporalMonitor, VectorFrontier}

  test "distributed runtime controls preserve bounded deterministic evidence" do
    assert Lease.valid?(%Lease{holder: :a, generation: 1, starts_at: 0, expires_at: 10}, 9)
    assert :concurrent = VectorFrontier.compare(%{a: 1}, %{b: 1})
    assert EffectiveQuorum.admit?(3, 0.0, 3)
    assert {:open, 2} = CircuitBreaker.transition(:closed, {:failure, 1}, 2)
    assert ConsistentRing.owner([:a,:b], "key") in [:a,:b]
    assert TemporalMonitor.eventually?([:cold,:hot], &(&1 == :hot), 1)
    assert is_binary(ReplayChain.root([%{x: 1}, %{y: 2}]))
    assert :build_broken = FailureDominance.worst([:alive,:build_broken,:partial_alive])
  end
end
