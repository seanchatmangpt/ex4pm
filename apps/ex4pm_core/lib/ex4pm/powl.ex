defmodule Ex4pm.POWL.Task do
  @moduledoc "A task node in an executable partial-order workflow."
  @enforce_keys [:id]
  defstruct [:id, :label, :intent, metadata: %{}]
end

defmodule Ex4pm.POWL do
  @moduledoc "Canonical bounded partial-order workflow model."

  alias Ex4pm.POWL.Task
  alias Ex4pm.Refusal

  @enforce_keys [:tasks, :edges]
  defstruct [:tasks, :edges, metadata: %{}]

  def new(tasks, edges, metadata \\ %{}) do
    with {:ok, task_map} <- normalize_tasks(tasks),
         {:ok, normalized_edges} <- normalize_edges(edges, task_map),
         :ok <- acyclic?(task_map, normalized_edges) do
      {:ok, %__MODULE__{tasks: task_map, edges: normalized_edges, metadata: metadata}}
    end
  end

  def layers(%__MODULE__{tasks: tasks, edges: edges}) do
    indegree = Enum.reduce(edges, Map.new(tasks, fn {id, _} -> {id, 0} end), fn {_from, to}, acc -> Map.update!(acc, to, &(&1 + 1)) end)
    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))
    do_layers(indegree, successors, [])
  end

  defp normalize_tasks(tasks) when is_list(tasks) do
    tasks
    |> Enum.reduce_while({:ok, %{}}, fn
      %Task{id: id} = task, {:ok, acc} ->
        id = to_string(id)
        {:cont, {:ok, Map.put(acc, id, %{task | id: id}}}}

      map, {:ok, acc} when is_map(map) ->
        id = Map.get(map, :id) || Map.get(map, "id")

        if is_nil(id) do
          {:halt, {:error, Refusal.new(:missing_task_id, "POWL task is missing identity", subject: map)}}
        else
          id = to_string(id)

          task = %Task{
            id: id,
            label: Map.get(map, :label) || Map.get(map, "label") || id,
            intent: Map.get(map, :intent) || Map.get(map, "intent"),
            metadata: Map.get(map, :metadata) || Map.get(map, "metadata") || %{}
          }

          {:cont, {:ok, Map.put(acc, id, task)}}
        end

      other, _acc ->
        {:halt, {:error, Refusal.new(:invalid_task, "POWL task must be a task struct or map", subject: other)}}
    end)
  end

  defp normalize_tasks(other) do
    {:error, Refusal.new(:invalid_tasks, "POWL tasks must be a list", subject: other)}
  end

  defp normalize_edges(edges, tasks) when is_list(edges) do
    edges
    |> Enum.reduce_while({:ok, []}, fn
      {from, to}, {:ok, acc} -> normalize_edge(from, to, tasks, acc)
      [from, to], {:ok, acc} -> normalize_edge(from, to, tasks, acc)
      other, _acc -> {:halt, {:error, Refusal.new(:invalid_edge, "POWL edge must contain from/to", subject: other)}}
    end)
    |> then(fn
      {:ok, normalized} -> {:ok, normalized |> Enum.uniq() |> Enum.sort()}
      error -> error
    end)
  end

  defp normalize_edges(other, _tasks) do
    {:error, Refusal.new(:invalid_edges, "POWL edges must be a list", subject: other)}
  end

  defp normalize_edge(from, to, tasks, acc) do
    from = to_string(from)
    to = to_string(to)

    cond do
      from == to -> {:halt, {:error, Refusal.new(:self_cycle, "POWL edge cannot self-reference", details: %{task: from})}}
      not Map.has_key?(tasks, from) -> {:halt, {:error, Refusal.new(:unknown_task, "POWL edge source is unknown", details: %{task: from})}}
      not Map.has_key?(tasks, to) -> {:halt, {:error, Refusal.new(:unknown_task, "POWL edge target is unknown", details: %{task: to})}}
      true -> {:cont, {:ok, [{from, to} | acc]}}
    end
  end

  defp acyclic?(tasks, edges) do
    indegree = Enum.reduce(edges, Map.new(tasks, fn {id, _} -> {id, 0} end), fn {_from, to}, acc -> Map.update!(acc, to, &(&1 + 1)) end)
    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    case consume_acyclic(indegree, successors, 0) do
      count when count == map_size(tasks) -> :ok
      _ -> {:error, Refusal.new(:cyclic_powl, "POWL partial-order graph contains a cycle")}
    end
  end

  defp consume_acyclic(indegree, successors, count) do
    zeros = indegree |> Enum.filter(fn {_id, degree} -> degree == 0 end) |> Enum.map(&elem(&1, 0))

    if zeros == [] do
      count
    else
      next =
        Enum.reduce(zeros, Map.drop(indegree, zeros), fn id, acc ->
          Enum.reduce(Map.get(successors, id, []), acc, fn successor, degrees -> Map.update!(degrees, successor, &(&1 - 1)) end)
        end)

      consume_acyclic(next, successors, count + length(zeros))
    end
  end

  defp do_layers(indegree, successors, acc) when map_size(indegree) == 0, do: Enum.reverse(acc)

  defp do_layers(indegree, successors, acc) do
    layer = indegree |> Enum.filter(fn {_id, degree} -> degree == 0 end) |> Enum.map(&elem(&1, 0)) |> Enum.sort()

    next =
      Enum.reduce(layer, Map.drop(indegree, layer), fn id, degrees ->
        Enum.reduce(Map.get(successors, id, []), degrees, fn successor, current -> Map.update!(current, successor, &(&1 - 1)) end)
      end)

    do_layers(next, successors, [layer | acc])
  end
end
