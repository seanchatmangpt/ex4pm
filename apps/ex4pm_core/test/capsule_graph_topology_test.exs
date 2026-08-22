defmodule Ex4pmCore.CapsuleGraph.TopologyTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Topology

  test "blocked capsule edge preserves other reversible alternatives" do
    assert {:ok, ["beam", "remote"]} = Topology.available(["remote", "oci", "beam"], ["oci"])

    assert {:error, {:blocked, :all_capsule_edges_unavailable}} =
             Topology.available(["oci"], ["oci"])
  end
end
