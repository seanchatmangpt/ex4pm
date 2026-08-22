defmodule Ex4pm.POWL.Task do
  @moduledoc """
  A task atom in the bounded strict-partial-order POWL kernel.

  This type is intentionally smaller than the recursive POWL 2.0 execution
  representation in `Ex4pmEngine.POWL`: it carries task identity, optional
  intent, and metadata for the canonical core partial-order relation.
  """

  @enforce_keys [:id]
  defstruct [:id, :label, :intent, metadata: %{}]
end

defmodule Ex4pm.POWL do
  @moduledoc """
  Canonical bounded strict-partial-order kernel for POWL.

  For a task set `T`, this module admits a relation `≺ ⊆ T × T` only when it is
  a **strict partial order**:

      ∀t∈T : ¬(t ≺ t)
      ∀a,b,c∈T : (a ≺ b ∧ b ≺ c) ⇒ a ≺ c

  Irreflexivity plus transitivity implies asymmetry. Callers may provide a
  Hasse-style cover relation; `new/3` stores its transitive closure so the
  resulting `edges` field is the mathematical relation itself, not merely one
  graph encoding of it.

  This module is the core partial-order primitive. Recursive POWL 2.0 choice
  graphs, `τ`, language semantics `ℒ`, and WF-net projection are implemented by
  `Ex4pmEngine.POWL`; they are not duplicated here.

  ## Executable transitivity

      iex> alias Ex4pm.POWL
      iex> {:ok, model} =
      ...>   POWL.new(
      ...>     [%{id: "a"}, %{id: "b"}, %{id: "c"}],
      ...>     [{"a", "b"}, {"b", "c"}]
      ...>   )
      iex> POWL.precedes?(model, "a", "c")
      true
      iex> {"a", "c"} in model.edges
      true
      iex> POWL.layers(model)
      [["a"], ["b"], ["c"]]

  With no ordering relation, tasks are concurrent at this kernel boundary:

      iex> {:ok, model} = Ex4pm.POWL.new([%{id: "a"}, %{id: "b"}], [])
      iex> Ex4pm.POWL.layers(model)
      [["a", "b"]]

  ## References

  The strict-partial-order interpretation follows H. Kourani and S. J. van
  Zelst, “POWL: Partially Ordered Workflow Language”, BPM 2023,
  DOI 10.1007/978-3-031-41620-0_6, and the generalized POWL 2.0 definition in
  H. Kourani, G. Park, and W. M. P. van der Aalst, “A discovery technique for
  expressive yet sound process models”, Process Science 3, 14 (2026),
  DOI 10.1007/s44311-026-00046-8.
  """

  alias Ex4pm.POWL.Task
  alias Ex4pm.Refusal

  @enforce_keys [:tasks, :edges]
  defstruct [:tasks, :edges, metadata: %{}]

  @type t :: %__MODULE__{
          tasks: %{optional(String.t()) => Task.t()},
          edges: [{String.t(), String.t()}],
          metadata: map()
        }

  @doc """
  Constructs a bounded strict partial order.

  Input edges may be the full relation or only a cover relation. The admitted
  model always stores the deterministic transitive closure.
  """
  def new(tasks, edges, metadata \\ %{}) do
    with {:ok, task_map} <- normalize_tasks(tasks),
         {:ok, normalized_edges} <- normalize_edges(edges, task_map),
         :ok <- acyclic?(task_map, normalized_edges) do
      relation = transitive_closure(normalized_edges)
      {:ok, %__MODULE__{tasks: task_map, edges: relation, metadata: metadata}}
    end
  end

  @doc """
  Returns whether `left ≺ right` belongs to the admitted strict partial order.

      iex> {:ok, m} = Ex4pm.POWL.new([%{id: :a}, %{id: :b}], [a: :b])
      iex> Ex4pm.POWL.precedes?(m, :a, :b)
      true
  """
  def precedes?(%__MODULE__{edges: edges}, left, right) do
    {to_string(left), to_string(right)} in edges
  end

  @doc """
  Returns deterministic topological strata of the strict partial order.

  Tasks within one returned layer are pairwise unordered at that frontier.
  """
  def layers(%__MODULE__{tasks: tasks, edges: edges}) do
    indegree =
      Enum.reduce(edges, Map.new(tasks, fn {id, _} -> {id, 0} end), fn {_from, to}, acc ->
        Map.update!(acc, to, &(&1 + 1))
      end)

    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))
    do_layers(indegree, successors, [])
  end

  defp normalize_tasks(tasks) when is_list(tasks) do
    tasks
    |> Enum.reduce_while({:ok, %{}}, fn
      %Task{id: id} = task, {:ok, acc} ->
        id = to_string(id)
        {:cont, {:ok, Map.put(acc, id, %{task | id: id})}}

      map, {:ok, acc} when is_map(map) ->
        id = Map.get(map, :id) || Map.get(map, "id")

        if is_nil(id) do
          {:halt,
           {:error, Refusal.new(:missing_task_id, "POWL task is missing identity", subject: map)}}
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
        {:halt,
         {:error,
          Refusal.new(:invalid_task, "POWL task must be a task struct or map", subject: other)}}
    end)
  end

  defp normalize_tasks(other) do
    {:error, Refusal.new(:invalid_tasks, "POWL tasks must be a list", subject: other)}
  end

  defp normalize_edges(edges, tasks) when is_list(edges) do
    edges
    |> Enum.reduce_while({:ok, []}, fn
      {from, to}, {:ok, acc} ->
        normalize_edge(from, to, tasks, acc)

      [from, to], {:ok, acc} ->
        normalize_edge(from, to, tasks, acc)

      other, _acc ->
        {:halt,
         {:error, Refusal.new(:invalid_edge, "POWL edge must contain from/to", subject: other)}}
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
      from == to ->
        {:halt,
         {:error,
          Refusal.new(:self_cycle, "POWL relation cannot self-reference", details: %{task: from})}}

      not Map.has_key?(tasks, from) ->
        {:halt,
         {:error,
          Refusal.new(:unknown_task, "POWL edge source is unknown", details: %{task: from})}}

      not Map.has_key?(tasks, to) ->
        {:halt,
         {:error, Refusal.new(:unknown_task, "POWL edge target is unknown", details: %{task: to})}}

      true ->
        {:cont, {:ok, [{from, to} | acc]}}
    end
  end

  defp transitive_closure(edges) do
    edges
    |> MapSet.new()
    |> close_relation()
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp close_relation(relation) do
    inferred =
      for {a, b} <- relation,
          {c, d} <- relation,
          b == c,
          into: MapSet.new(),
          do: {a, d}

    next = MapSet.union(relation, inferred)
    if MapSet.equal?(next, relation), do: relation, else: close_relation(next)
  end

  defp acyclic?(tasks, edges) do
    indegree =
      Enum.reduce(edges, Map.new(tasks, fn {id, _} -> {id, 0} end), fn {_from, to}, acc ->
        Map.update!(acc, to, &(&1 + 1))
      end)

    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    case consume_acyclic(indegree, successors, 0) do
      count when count == map_size(tasks) -> :ok
      _ -> {:error, Refusal.new(:cyclic_powl, "POWL strict partial order contains a cycle")}
    end
  end

  defp consume_acyclic(indegree, successors, count) do
    zeros =
      indegree
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(&elem(&1, 0))

    if zeros == [] do
      count
    else
      next =
        Enum.reduce(zeros, Map.drop(indegree, zeros), fn id, acc ->
          Enum.reduce(Map.get(successors, id, []), acc, fn successor, degrees ->
            Map.update!(degrees, successor, &(&1 - 1))
          end)
        end)

      consume_acyclic(next, successors, count + length(zeros))
    end
  end

  defp do_layers(indegree, _successors, acc) when map_size(indegree) == 0,
    do: Enum.reverse(acc)

  defp do_layers(indegree, successors, acc) do
    layer =
      indegree
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    next =
      Enum.reduce(layer, Map.drop(indegree, layer), fn id, degrees ->
        Enum.reduce(Map.get(successors, id, []), degrees, fn successor, current ->
          Map.update!(current, successor, &(&1 - 1))
        end)
      end)

    do_layers(next, successors, [layer | acc])
  end
end
