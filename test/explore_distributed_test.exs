defmodule Ex4pm.Explore.DistributedTest do
  use ExUnit.Case, async: true

  test "vector clocks expose concurrency while Lamport clocks totalize" do
    a = Ex4pm.Explore.VectorClock.tick(%{}, :a)
    b = Ex4pm.Explore.VectorClock.tick(%{}, :b)
    assert Ex4pm.Explore.VectorClock.compare(a, b) == :concurrent
    assert Ex4pm.Explore.LamportClock.receive(1, 1) == 2
  end

  test "quorum calculus enforces read/write intersection" do
    assert Ex4pm.Explore.Quorum.majority(5) == 3
    assert Ex4pm.Explore.Quorum.safe_read_write?(5, 3, 3)
    refute Ex4pm.Explore.Quorum.safe_read_write?(5, 2, 2)
  end
end
