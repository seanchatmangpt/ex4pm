defmodule Ex4pmCore.CapsuleGraph.Currentness.Dependency do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Currentness.{FixedPoint, Lattice}

  def propagate(graph, standings) when is_map(graph) and is_map(standings) do
    FixedPoint.close(standings, fn state ->
      Enum.reduce(graph, state, fn {node, deps}, acc ->
        dependency_states = Enum.map(deps, &Map.get(acc, &1, :unknown))
        Map.put(acc, node, Lattice.join([Map.get(acc, node, :unknown) | dependency_states]))
      end)
    end)
  end
end
