defmodule Ex4pmCore.CapsuleCurrentnessLeaseTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.Lease

  test "lease is active on left edge and expired on right edge" do
    assert {:ok, lease} = Lease.new(10, 20)
    assert Lease.active?(lease, 10)
    refute Lease.active?(lease, 20)
    assert {:error, {:refused, :invalid_lease}} = Lease.new(20, 20)
  end
end
