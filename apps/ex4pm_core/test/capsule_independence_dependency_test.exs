defmodule Ex4pmCore.CapsuleIndependenceDependencyTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Independence.{Dependency, Standing}

  test "dependency cycles refuse and red dependencies dominate local evidence" do
    assert {:error, {:refused, :dependency_cycle}} =
             Dependency.blockers(%{"a" => ["b"], "b" => ["a"]}, %{
               "a" => :partial_alive,
               "b" => :build_broken
             })

    assert {:ok, ["b"]} =
             Dependency.blockers(%{"a" => ["b"], "b" => []}, %{
               "a" => :partial_alive,
               "b" => :build_broken
             })

    assert Standing.combine([:partial_alive, :build_broken]) == :build_broken
    assert Standing.cap_positive(:alive) == :partial_alive
  end
end
