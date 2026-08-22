defmodule Ex4pmCore.CapsuleGraph.CompatibilityTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.{Capability, Compatibility}

  test "requires exact capability protocol compatibility" do
    {:ok, planner_v1} = Capability.new(:plan, "ex4pm-plan/v1")
    {:ok, planner_v2} = Capability.new(:plan, "ex4pm-plan/v2")

    assert {:ok, :compatible} = Compatibility.verify([planner_v1], [planner_v1])

    assert {:error, {:unsupported, :missing_capabilities, [^planner_v2]}} =
             Compatibility.verify([planner_v1], [planner_v2])
  end
end
