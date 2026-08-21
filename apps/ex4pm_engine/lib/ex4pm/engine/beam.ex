defmodule Ex4pm.Engine.Beam do
  @moduledoc "Deterministic native-BEAM process-mining baseline."

  @behaviour Ex4pm.Engine

  alias Ex4pm.{EventLog, OCEL, Refusal}
  alias Ex4pm.Engine.Result

  @impl true
  def id, do: :beam

  @impl true
  def supports?(operation, _opts), do: operation in [:discover, :conform, :simulate, :optimize]

  @impl true
  def available?(_opts), do: true

  @impl true
  def execute(:discover, %EventLog{} = log, opts) do
    algorithm = Keyword.get(opts, :algorithm, :dfg)

    case algorithm do
      :dfg -> discover_dfg(log, opts)
      :variants -> discover_variants(log, opts)
      other ->
        {:error,
         Refusal.new(:unsupported_algorithm, "BEAM engine does not implement discovery algorithm",
           details: %{algorithm: other}
         )}
    end
  end

  def execute(:conform, {%EventLog{} = log, model}, opts), do: conform(log, model, opts)
  def execute(:simulate, model, opts) when is_map(model), do: simulate(model, opts)
  def execute(:optimize, {%EventLog{} = log, model}, opts), do: optimize(log, model, opts)

  def execute(operation, subject, _opts) do
    {:error,
     Refusal.new(:invalid_engine_subject, "BEAM operation received an invalid subject",
       subject: subject,
       details: %{operation: operation}
     )}
  end

  defp discover_dfg(log, opts) do
    object_type = Keyword.get(opts, :object_type)

    with {:ok, traces} <- OCEL.flatten(log, object_type) do
      activities =
        traces
        |> Map.values()
        |> List.flatten()
        |> Enum.frequencies_by(& &1.activity)

      edges =
        traces
        |> Enum.flat_map(fn {_case_id, events} ->
          events
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [left, right] ->
            {{left.activity, right.activity}, duration_ms(left.timestamp, right.timestamp)}
          end)
        end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Map.new(fn {edge, durations} ->
          valid = Enum.reject(durations, &is_nil/1)
          average = if valid == [], do: nil, else: Enum.sum(valid) / length(valid)
          {edge, %{count: length(durations), average_duration_ms: average}}
        end)

      starts =
        traces
        |> Map.values()
        |> Enum.reject(&(&1 == []))
        |> Enum.map(&hd(&1).activity)
        |> Enum.frequencies()

      ends =
        traces
        |> Map.values()
        |> Enum.reject(&(&1 == []))
        |> Enum.map(&List.last(&1).activity)
        |> Enum.frequencies()

      model = %{
        type: :dfg,
        object_type: object_type,
        activities: activities,
        edges: edges,
        starts: starts,
        ends: ends,
        trace_count: map_size(traces)
      }

      {:ok,
       %Result{
         engine: :beam,
         operation: :discover,
         algorithm: :dfg,
         subject_hash: log.subject.hash,
         standing: :alive,
         value: model,
         evidence: %{traces: map_size(traces), deterministic: true}
       }}
    end
  end

  defp discover_variants(log, opts) do
    with {:ok, traces} <- OCEL.flatten(log, Keyword.get(opts, :object_type)) do
      variants =
        traces
        |> Map.values()
        |> Enum.map(fn events -> Enum.map(events, & &1.activity) end)
        |> Enum.frequencies()

      {:ok,
       %Result{
         engine: :beam,
         operation: :discover,
         algorithm: :variants,
         subject_hash: log.subject.hash,
         standing: :alive,
         value: %{type: :variants, variants: variants, trace_count: map_size(traces)},
         evidence: %{deterministic: true}
       }}
    end
  end

  defp conform(log, %{type: :dfg, edges: model_edges} = model, opts) do
    object_type = Keyword.get(opts, :object_type, Map.get(model, :object_type))

    with {:ok, traces} <- OCEL.flatten(log, object_type) do
      observed_edges =
        traces
        |> Map.values()
        |> Enum.flat_map(fn events ->
          events
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [left, right] -> {left.activity, right.activity} end)
        end)

      deviations = Enum.reject(observed_edges, &Map.has_key?(model_edges, &1))
      total = length(observed_edges)
      fitness = if total == 0, do: 1.0, else: max(0.0, 1.0 - length(deviations) / total)

      report = %{
        type: :dfg_conformance,
        fitness: fitness,
        observed_edge_count: total,
        deviation_count: length(deviations),
        deviations: Enum.frequencies(deviations)
      }

      {:ok,
       %Result{
         engine: :beam,
         operation: :conform,
         algorithm: :dfg_tokenless,
         subject_hash: log.subject.hash,
         standing: :alive,
         value: report,
         evidence: %{deterministic: true}
       }}
    end
  end

  defp conform(_log, model, _opts) do
    {:error, Refusal.new(:unsupported_model, "conformance requires a DFG model", subject: model)}
  end

  defp simulate(%{type: :dfg} = model, opts) do
    max_depth = Keyword.get(opts, :max_depth, 12)
    max_paths = Keyword.get(opts, :max_paths, 128)
    adjacency = Enum.group_by(Map.keys(model.edges), &elem(&1, 0), &elem(&1, 1))
    starts = Map.keys(model.starts) |> Enum.sort()
    ends = Map.keys(model.ends) |> MapSet.new()

    paths =
      starts
      |> Enum.flat_map(fn start -> explore(start, adjacency, ends, max_depth, [start]) end)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.take(max_paths)

    {:ok,
     %Result{
       engine: :beam,
       operation: :simulate,
       algorithm: :bounded_dfg_paths,
       subject_hash: Ex4pm.Core.Hash.digest(model),
       standing: :alive,
       value: %{paths: paths, path_count: length(paths), max_depth: max_depth, max_paths: max_paths},
       evidence: %{bounded: true, deterministic: true}
     }}
  end

  defp simulate(model, _opts) do
    {:error, Refusal.new(:unsupported_model, "simulation requires a DFG model", subject: model)}
  end

  defp optimize(log, %{type: :dfg, edges: edges} = model, _opts) do
    candidates =
      edges
      |> Enum.filter(fn {_edge, stats} -> is_number(stats.average_duration_ms) end)
      |> Enum.sort_by(fn {edge, stats} -> {-stats.average_duration_ms, edge} end)
      |> Enum.take(10)
      |> Enum.map(fn {edge, stats} ->
        %{
          kind: :reduce_handoff_delay,
          edge: edge,
          observed_average_duration_ms: stats.average_duration_ms,
          occurrence_count: stats.count,
          mode: :construct_only,
          authority: :none
        }
      end)

    {:ok,
     %Result{
       engine: :beam,
       operation: :optimize,
       algorithm: :duration_bottlenecks,
       subject_hash: log.subject.hash,
       standing: :alive,
       value: %{model_hash: Ex4pm.Core.Hash.digest(model), candidates: candidates},
       evidence: %{candidate_count: length(candidates), actuated: false}
     }}
  end

  defp optimize(_log, model, _opts) do
    {:error, Refusal.new(:unsupported_model, "optimization requires a DFG model", subject: model)}
  end

  defp explore(current, _adjacency, ends, depth, path) when depth <= 1 do
    if MapSet.member?(ends, current), do: [Enum.reverse(path)], else: [Enum.reverse(path)]
  end

  defp explore(current, adjacency, ends, depth, path) do
    next = Map.get(adjacency, current, []) |> Enum.sort()

    cond do
      MapSet.member?(ends, current) -> [Enum.reverse(path)]
      next == [] -> [Enum.reverse(path)]
      true ->
        Enum.flat_map(next, fn activity ->
          explore(activity, adjacency, ends, depth - 1, [activity | path])
        end)
    end
  end

  defp duration_ms(left, right) do
    with {:ok, left_dt, _} <- DateTime.from_iso8601(left),
         {:ok, right_dt, _} <- DateTime.from_iso8601(right) do
      DateTime.diff(right_dt, left_dt, :millisecond)
    else
      _ -> nil
    end
  end
end
