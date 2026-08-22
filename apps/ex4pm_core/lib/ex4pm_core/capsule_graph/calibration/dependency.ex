defmodule Ex4pmCore.CapsuleGraph.Calibration.Dependency do
  @moduledoc false

  @spec blockers(map(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def blockers(graph, root) when is_map(graph) and is_binary(root) do
    visit(graph, root, MapSet.new(), MapSet.new())
    |> case do
      {:ok, {_seen, blocked}} -> {:ok, blocked |> MapSet.to_list() |> Enum.sort()}
      other -> other
    end
  end

  def blockers(_, _), do: {:error, {:refused, :invalid_dependency_graph}}

  defp visit(graph, node, stack, seen) do
    cond do
      MapSet.member?(stack, node) -> {:error, {:refused, :dependency_cycle}}
      MapSet.member?(seen, node) -> {:ok, {seen, MapSet.new()}}
      true ->
        entry = Map.get(graph, node, %{standing: :unknown, dependencies: []})
        next_stack = MapSet.put(stack, node)
        next_seen = MapSet.put(seen, node)
        own = if entry.standing in [:blocked, :build_broken], do: MapSet.new([node]), else: MapSet.new()

        Enum.reduce_while(entry.dependencies, {:ok, {next_seen, own}}, fn dep, {:ok, {s, acc}} ->
          case visit(graph, dep, next_stack, s) do
            {:ok, {s2, b}} -> {:cont, {:ok, {s2, MapSet.union(acc, b)}}}
            error -> {:halt, error}
          end
        end)
    end
  end
end
