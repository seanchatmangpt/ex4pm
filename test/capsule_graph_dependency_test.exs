defmodule Ex4pmCore.CapsuleGraph.DependencyTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.{Dependency, Subject}

  test "orders closed dependencies and refuses cycles" do
    {:ok, ex4pm} = Subject.new("seanchatmangpt/ex4pm", String.duplicate("1", 40))
    {:ok, planner} = Subject.new("seanchatmangpt/ex4pm-plan", String.duplicate("2", 40))

    assert {:ok, ordered} = Dependency.order([ex4pm, planner], [{ex4pm, planner}])
    assert length(ordered) == 2

    assert {:error, {:refused, :capsule_dependency_cycle}} =
             Dependency.order([ex4pm, planner], [{ex4pm, planner}, {planner, ex4pm}])
  end
end
