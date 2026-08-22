defmodule Ex4pmCore.CapsuleCurrentnessDependencyTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.Dependency

  test "broken dependency dominates downstream standing" do
    graph = %{consumer: [:producer], producer: []}
    assert {:ok, standings} = Dependency.propagate(graph, %{producer: :build_broken, consumer: :partial_alive})
    assert standings.consumer == :build_broken
    assert standings.producer == :build_broken
  end
end
