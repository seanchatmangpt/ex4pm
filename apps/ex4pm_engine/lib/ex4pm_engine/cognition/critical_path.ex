defmodule Ex4pmEngine.Cognition.CriticalPath do
  @moduledoc """
  Critical Path Method (CPM) Scheduler for multi-agent DAG task execution.
  Calculates Earliest Start (ES), Latest Start (LS), Total Float/Slack,
  and identifies the critical path through task dependencies.
  """

  defmodule Task do
    @enforce_keys [:id, :duration_ms]
    defstruct [:id, :duration_ms, dependencies: [], metadata: %{}]
  end

  @doc """
  Computes the Critical Path analysis over a list of `%Task{}` structs.
  """
  def analyze_schedule(tasks) when is_list(tasks) do
    task_map = Map.new(tasks, &{&1.id, &1})

    # Forward pass: Earliest Start (ES) and Earliest Finish (EF)
    # Topological order
    sorted_ids = topological_sort(tasks)

    earliest =
      Enum.reduce(sorted_ids, %{}, fn task_id, acc ->
        task = Map.fetch!(task_map, task_id)

        es =
          if task.dependencies == [] do
            0
          else
            Enum.map(task.dependencies, fn dep_id ->
              Map.fetch!(acc, dep_id).ef
            end)
            |> Enum.max()
          end

        ef = es + task.duration_ms
        Map.put(acc, task_id, %{es: es, ef: ef})
      end)

    total_project_duration =
      earliest
      |> Map.values()
      |> Enum.map(& &1.ef)
      |> Enum.max(fn -> 0 end)

    # Backward pass: Latest Finish (LF) and Latest Start (LS)
    # Reverse topological order
    reverse_deps = build_reverse_deps(tasks)

    latest =
      Enum.reduce(Enum.reverse(sorted_ids), %{}, fn task_id, acc ->
        task = Map.fetch!(task_map, task_id)
        successors = Map.get(reverse_deps, task_id, [])

        lf =
          if successors == [] do
            total_project_duration
          else
            Enum.map(successors, fn succ_id ->
              Map.fetch!(acc, succ_id).ls
            end)
            |> Enum.min()
          end

        ls = lf - task.duration_ms
        slack = ls - Map.fetch!(earliest, task_id).es
        Map.put(acc, task_id, %{lf: lf, ls: ls, slack: slack})
      end)

    # Critical path is all tasks where slack == 0
    critical_path =
      sorted_ids
      |> Enum.filter(fn id -> Map.fetch!(latest, id).slack == 0 end)

    schedule_table =
      Map.new(sorted_ids, fn id ->
        e = Map.fetch!(earliest, id)
        l = Map.fetch!(latest, id)

        {id,
         %{
           duration_ms: Map.fetch!(task_map, id).duration_ms,
           earliest_start: e.es,
           earliest_finish: e.ef,
           latest_start: l.ls,
           latest_finish: l.lf,
           slack: l.slack,
           critical?: l.slack == 0
         }}
      end)

    %{
      total_duration_ms: total_project_duration,
      critical_path: critical_path,
      task_schedules: schedule_table
    }
  end

  defp topological_sort(tasks) do
    # Simple Kahn's algorithm
    in_degrees = Map.new(tasks, fn t -> {t.id, length(t.dependencies)} end)
    reverse_deps = build_reverse_deps(tasks)

    zero_queue =
      in_degrees
      |> Enum.filter(fn {_id, deg} -> deg == 0 end)
      |> Enum.map(&elem(&1, 0))

    kahn_loop(zero_queue, in_degrees, reverse_deps, [])
  end

  defp kahn_loop([], _in_degrees, _rev_deps, acc), do: Enum.reverse(acc)

  defp kahn_loop([current | rest], in_degrees, rev_deps, acc) do
    successors = Map.get(rev_deps, current, [])

    new_in_degrees =
      Enum.reduce(successors, in_degrees, fn succ, degs ->
        Map.update!(degs, succ, &(&1 - 1))
      end)

    new_zeros =
      Enum.filter(successors, fn succ ->
        Map.fetch!(new_in_degrees, succ) == 0
      end)

    kahn_loop(rest ++ new_zeros, new_in_degrees, rev_deps, [current | acc])
  end

  defp build_reverse_deps(tasks) do
    tasks
    |> Enum.flat_map(fn t ->
      Enum.map(t.dependencies, fn dep -> {dep, t.id} end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end
end
