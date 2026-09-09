defmodule Ex4pmEngine.Beam.SoundnessGraphTest do
  @moduledoc """
  Real, no-mock coverage of `Ex4pmEngine.Beam.SoundnessGraph` against literal
  POWL-shaped fixtures -- a real `:digraph.graph()` built and torn down per
  call, state-based assertions on the returned standing tuple.
  """
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Beam.SoundnessGraph

  test "a fully connected acyclic model is real :alive with every vertex listed" do
    model = %{start: :a, arcs: [{:a, :b}, {:b, :c}, {:a, :c}]}

    assert {:alive, %{vertices: vertices}} = SoundnessGraph.check(model)
    assert Enum.sort(vertices) == [:a, :b, :c]
  end

  test "a model with a vertex unreachable from start is real :blocked and names it" do
    model = %{start: :a, arcs: [{:a, :b}, {:c, :d}]}

    assert {:blocked, {:unreachable_vertices, unreachable}} = SoundnessGraph.check(model)
    assert Enum.sort(unreachable) == [:c, :d]
  end

  test "a model with a real cycle is real :blocked and reports the cycle" do
    model = %{start: :a, arcs: [{:a, :b}, {:b, :c}, {:c, :b}]}

    assert {:blocked, {:cycle_detected, cycle}} = SoundnessGraph.check(model)
    assert :b in cycle
    assert :c in cycle
  end

  test "a single-vertex model with no arcs is real :alive" do
    model = %{start: :only, arcs: []}

    # :digraph never sees :only as a vertex unless it appears in an arc --
    # confirm the real, honest behavior rather than assuming.
    assert {:alive, %{vertices: []}} = SoundnessGraph.check(model)
  end

  test "build/1 produces a real :digraph.graph() the caller owns" do
    graph = SoundnessGraph.build(%{arcs: [{:a, :b}]})

    assert :digraph.vertices(graph) |> Enum.sort() == [:a, :b]
    assert :digraph.edges(graph) |> length() == 1

    :digraph.delete(graph)
  end
end
