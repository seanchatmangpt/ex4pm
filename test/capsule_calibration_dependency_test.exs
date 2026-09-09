defmodule Ex4pmCore.CapsuleCalibrationDependencyTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Calibration.Dependency

  test "red dependencies propagate and cycles refuse" do
    graph = %{
      "root" => %{standing: :partial_alive, dependencies: ["mid"]},
      "mid" => %{standing: :partial_alive, dependencies: ["leaf"]},
      "leaf" => %{standing: :build_broken, dependencies: []}
    }

    assert {:ok, ["leaf"]} = Dependency.blockers(graph, "root")

    cyclic = %{
      "a" => %{standing: :unknown, dependencies: ["b"]},
      "b" => %{standing: :unknown, dependencies: ["a"]}
    }

    assert {:error, {:refused, :dependency_cycle}} = Dependency.blockers(cyclic, "a")
  end
end
