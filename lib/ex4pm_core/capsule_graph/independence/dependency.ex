defmodule Ex4pmCore.CapsuleGraph.Independence.Dependency do
  @moduledoc false

  @blocking [:build_broken, :blocked]

  def blockers(dependencies, standings) when is_map(dependencies) and is_map(standings) do
    with :ok <- acyclic(dependencies) do
      blocked =
        standings
        |> Enum.filter(fn {_subject, standing} -> standing in @blocking end)
        |> Enum.map(&elem(&1, 0))
        |> Enum.sort()

      {:ok, blocked}
    end
  end

  def blockers(_, _), do: {:error, {:refused, :invalid_dependency_evidence}}

  defp acyclic(graph) do
    if Enum.any?(Map.keys(graph), &cycle?(graph, &1, MapSet.new())) do
      {:error, {:refused, :dependency_cycle}}
    else
      :ok
    end
  end

  defp cycle?(graph, node, path) do
    if MapSet.member?(path, node) do
      true
    else
      next_path = MapSet.put(path, node)
      Enum.any?(Map.get(graph, node, []), &cycle?(graph, &1, next_path))
    end
  end
end
