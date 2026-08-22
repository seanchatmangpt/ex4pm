defmodule Ex4pm.Engine.OnlineMiner do
  @moduledoc """
  Supervised online process-mining state machine.

  Maintains streaming DFG topology, variant frequencies, agent fleet lifecycles,
  and real-time behavioral conformance against reference BEAM process contracts.
  """

  use GenServer

  alias Ex4pm.Event

  @default_canonical_flow [
    "admit",
    "construct",
    "verify",
    "brce",
    "do",
    "receipt",
    "replay",
    "standing"
  ]

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def ingest(event_or_events, server \\ __MODULE__) do
    GenServer.call(server, {:ingest, event_or_events})
  end

  def get_summary(server \\ __MODULE__) do
    GenServer.call(server, :get_summary)
  end

  def get_dfg(server \\ __MODULE__) do
    GenServer.call(server, :get_dfg)
  end

  def get_fleet_status(server \\ __MODULE__) do
    GenServer.call(server, :get_fleet_status)
  end

  def get_variants(server \\ __MODULE__) do
    GenServer.call(server, :get_variants)
  end

  def get_conformance(server \\ __MODULE__) do
    GenServer.call(server, :get_conformance)
  end

  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    subscriber = Keyword.get(opts, :subscriber)
    canonical_flow = Keyword.get(opts, :canonical_flow, @default_canonical_flow)

    state = %{
      subscriber: subscriber,
      canonical_flow: canonical_flow,
      total_events: 0,
      total_runs: 0,
      # agent_id => %{agent_id, run_id, state, last_activity, last_timestamp, event_count, standing, repo}
      agents: %{},
      # trace_id => [%Event{}]
      traces: %{},
      # {from, to} => %{count: integer, total_ms: number, min_ms: number, max_ms: number}
      dfg_edges: %{},
      # activity => count
      activity_counts: %{},
      starts: %{},
      ends: %{},
      # [activity_list] => count
      variants: %{},
      # Deviations / Anomaly tracking
      deviations: %{},
      conformance_stats: %{observed_transitions: 0, non_conformant_transitions: 0, fitness: 1.0},
      refusals: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:ingest, %Event{} = event}, _from, state) do
    new_state = process_event(event, state)
    maybe_notify(new_state, :event, event)
    {:reply, :ok, new_state}
  end

  def handle_call({:ingest, events}, _from, state) when is_list(events) do
    new_state = Enum.reduce(events, state, &process_event/2)
    maybe_notify(new_state, :batch, events)
    {:reply, {:ok, length(events)}, new_state}
  end

  def handle_call(:get_summary, _from, state) do
    active_agents =
      state.agents |> Map.values() |> Enum.filter(&(&1.state != :complete)) |> length()

    summary = %{
      total_events: state.total_events,
      active_agents: active_agents,
      total_agents: map_size(state.agents),
      total_variants: map_size(state.variants),
      dfg_edge_count: map_size(state.dfg_edges),
      conformance_fitness: state.conformance_stats.fitness,
      refusal_count: length(state.refusals)
    }

    {:reply, summary, state}
  end

  def handle_call(:get_dfg, _from, state) do
    edges =
      Map.new(state.dfg_edges, fn {{from, to}, stats} ->
        avg = if stats.count > 0, do: stats.total_ms / stats.count, else: 0.0

        {{from, to},
         %{
           count: stats.count,
           average_duration_ms: avg,
           min_duration_ms: stats.min_ms,
           max_duration_ms: stats.max_ms
         }}
      end)

    dfg = %{
      type: :dfg,
      activities: state.activity_counts,
      edges: edges,
      starts: state.starts,
      ends: state.ends,
      trace_count: map_size(state.traces)
    }

    {:reply, dfg, state}
  end

  def handle_call(:get_fleet_status, _from, state) do
    fleet =
      state.agents
      |> Map.values()
      |> Enum.sort_by(& &1.last_timestamp, :desc)

    {:reply, fleet, state}
  end

  def handle_call(:get_variants, _from, state) do
    variants =
      state.variants
      |> Enum.map(fn {path, count} -> %{path: path, count: count} end)
      |> Enum.sort_by(& &1.count, :desc)

    {:reply, variants, state}
  end

  def handle_call(:get_conformance, _from, state) do
    report = %{
      fitness: state.conformance_stats.fitness,
      observed_transitions: state.conformance_stats.observed_transitions,
      non_conformant_transitions: state.conformance_stats.non_conformant_transitions,
      deviations: state.deviations,
      canonical_flow: state.canonical_flow,
      recent_refusals: Enum.take(state.refusals, 20)
    }

    {:reply, report, state}
  end

  def handle_call(:reset, _from, _state) do
    {:ok, clean_state} = init([])
    {:reply, :ok, clean_state}
  end

  # Internal Process Intelligence Computation

  defp process_event(%Event{} = event, state) do
    agent_id =
      extract_attr(event, ["agent_id", :agent_id, "producer_id", :producer_id]) ||
        default_case_id(event)

    run_id = extract_attr(event, ["run_id", :run_id]) || agent_id
    standing = extract_attr(event, ["standing", :standing]) || :alive
    repo = extract_attr(event, ["repository", :repository, "repo", :repo])
    activity = event.activity

    # 1. Update activity frequencies
    new_activity_counts = Map.update(state.activity_counts, activity, 1, &(&1 + 1))

    # 2. Update agent trace and DFG edges
    trace = Map.get(state.traces, run_id, [])
    new_trace = [event | trace]
    new_traces = Map.put(state.traces, run_id, new_trace)

    {new_dfg, new_starts, new_conformance, new_deviations} =
      case trace do
        [] ->
          # First event in this trace
          updated_starts = Map.update(state.starts, activity, 1, &(&1 + 1))
          {state.dfg_edges, updated_starts, state.conformance_stats, state.deviations}

        [prev_event | _] ->
          # Transition prev_event.activity -> activity
          edge = {prev_event.activity, activity}
          duration = calculate_duration_ms(prev_event.timestamp, event.timestamp)

          updated_edges =
            Map.update(
              state.dfg_edges,
              edge,
              %{count: 1, total_ms: duration, min_ms: duration, max_ms: duration},
              fn stats ->
                %{
                  count: stats.count + 1,
                  total_ms: stats.total_ms + duration,
                  min_ms: min(stats.min_ms, duration),
                  max_ms: max(stats.max_ms, duration)
                }
              end
            )

          # Check conformance against canonical model
          is_conformant = is_transition_lawful?(edge, state.canonical_flow)

          obs = state.conformance_stats.observed_transitions + 1

          non_conf =
            state.conformance_stats.non_conformant_transitions + if(is_conformant, do: 0, else: 1)

          fitness = if obs > 0, do: max(0.0, 1.0 - non_conf / obs), else: 1.0

          updated_conf = %{
            observed_transitions: obs,
            non_conformant_transitions: non_conf,
            fitness: fitness
          }

          updated_devs =
            if is_conformant do
              state.deviations
            else
              Map.update(state.deviations, edge, 1, &(&1 + 1))
            end

          {updated_edges, state.starts, updated_conf, updated_devs}
      end

    # 3. Update active agent status
    agent_state = determine_agent_state(activity, standing)

    agent_record = %{
      agent_id: to_string(agent_id),
      run_id: to_string(run_id),
      state: agent_state,
      last_activity: activity,
      last_timestamp: event.timestamp,
      event_count: length(new_trace),
      standing: normalize_standing(standing),
      repository: repo
    }

    new_agents = Map.put(state.agents, agent_id, agent_record)

    # 4. Check refusals
    new_refusals =
      if String.starts_with?(to_string(activity), "refusal") or
           String.starts_with?(to_string(activity), "REFUSED") or standing in [:refused, :blocked] do
        [
          %{
            agent_id: agent_id,
            run_id: run_id,
            activity: activity,
            timestamp: event.timestamp,
            details: event.attributes
          }
          | state.refusals
        ]
      else
        state.refusals
      end

    # 5. Update variants (recomputed for this trace)
    trace_path = new_trace |> Enum.reverse() |> Enum.map(& &1.activity)
    # We remove the old variant instance and increment the new one
    new_variants = update_variants(state.variants, trace, trace_path)

    %{
      state
      | total_events: state.total_events + 1,
        agents: new_agents,
        traces: new_traces,
        dfg_edges: new_dfg,
        activity_counts: new_activity_counts,
        starts: new_starts,
        conformance_stats: new_conformance,
        deviations: new_deviations,
        refusals: new_refusals,
        variants: new_variants
    }
  end

  defp update_variants(variants, old_trace, new_path) do
    v1 =
      if old_trace != [] do
        old_path = old_trace |> Enum.reverse() |> Enum.map(& &1.activity)

        case Map.get(variants, old_path) do
          nil -> variants
          1 -> Map.delete(variants, old_path)
          count -> Map.put(variants, old_path, count - 1)
        end
      else
        variants
      end

    Map.update(v1, new_path, 1, &(&1 + 1))
  end

  defp is_transition_lawful?({from, to}, canonical_flow) do
    from_norm = normalize_activity(from)
    to_norm = normalize_activity(to)

    from_idx = Enum.find_index(canonical_flow, &(&1 == from_norm))
    to_idx = Enum.find_index(canonical_flow, &(&1 == to_norm))

    cond do
      is_nil(from_idx) or is_nil(to_idx) ->
        true

      # Forward progression or retry loop
      to_idx >= from_idx or (from_norm == "verify" and to_norm in ["construct", "admit"]) ->
        true

      true ->
        false
    end
  end

  defp normalize_activity(activity) do
    activity
    |> to_string()
    |> String.downcase()
    |> String.split(".")
    |> List.first()
  end

  defp determine_agent_state(activity, standing) do
    act = String.downcase(to_string(activity))

    cond do
      standing in [:refused, :blocked] or String.contains?(act, "refus") ->
        :refused

      String.contains?(act, "complete") or String.contains?(act, "finish") or
          String.contains?(act, "stop") ->
        :complete

      String.contains?(act, "verify") or String.contains?(act, "test") or
          String.contains?(act, "check") ->
        :verifying

      String.contains?(act, "construct") or String.contains?(act, "compile") or
          String.contains?(act, "edit") ->
        :constructing

      String.contains?(act, "do") or String.contains?(act, "exec") or String.contains?(act, "run") ->
        :executing

      true ->
        :alive
    end
  end

  defp normalize_standing(standing) when is_atom(standing), do: standing

  defp normalize_standing(standing) when is_binary(standing) do
    case String.downcase(standing) do
      "alive" -> :alive
      "partial_alive" -> :partial_alive
      "blocked" -> :blocked
      "refused" -> :refused
      "unsupported" -> :unsupported
      _ -> :unknown
    end
  end

  defp normalize_standing(_), do: :alive

  defp calculate_duration_ms(t1, t2) do
    with {:ok, dt1, _} <- DateTime.from_iso8601(to_string(t1)),
         {:ok, dt2, _} <- DateTime.from_iso8601(to_string(t2)) do
      max(0, DateTime.diff(dt2, dt1, :millisecond))
    else
      _ -> 0
    end
  end

  defp default_case_id(%Event{object_ids: [first | _]}), do: first
  defp default_case_id(%Event{id: id}), do: "case-#{id}"

  defp extract_attr(%Event{attributes: attrs}, keys) when is_map(attrs) do
    Enum.find_value(keys, fn k -> Map.get(attrs, k) end)
  end

  defp extract_attr(_event, _keys), do: nil

  defp maybe_notify(%{subscriber: subscriber} = state, event_type, payload)
       when is_function(subscriber, 2) do
    try do
      subscriber.(event_type, %{state: state, payload: payload})
    rescue
      _ -> :ok
    end
  end

  defp maybe_notify(_state, _type, _payload), do: :ok
end
