defmodule Ex4pmEngine.WorkflowNet.Place do
  @moduledoc "A place in a Petri net / Workflow Net."
  @enforce_keys [:id]
  defstruct [:id, name: nil, metadata: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t() | nil,
          metadata: map()
        }
end

defmodule Ex4pmEngine.WorkflowNet.Transition do
  @moduledoc "A transition in a Petri net / Workflow Net."
  @enforce_keys [:id]
  defstruct [:id, label: nil, silent?: false, metadata: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          label: String.t() | nil,
          silent?: boolean(),
          metadata: map()
        }
end

defmodule Ex4pmEngine.WorkflowNet.Arc do
  @moduledoc "A directed flow arc between Place -> Transition or Transition -> Place."
  @enforce_keys [:source, :target]
  defstruct [:source, :target, weight: 1, metadata: %{}]

  @type t :: %__MODULE__{
          source: String.t(),
          target: String.t(),
          weight: pos_integer(),
          metadata: map()
        }
end

defmodule Ex4pmEngine.WorkflowNet.SoundnessReport do
  @moduledoc "Comprehensive 1-safe bounded reachability soundness verification report."
  @enforce_keys [:sound?]
  defstruct [
    :sound?,
    definition_3_3_valid?: true,
    one_safe?: true,
    option_to_complete?: true,
    proper_completion?: true,
    no_dead_transitions?: true,
    dead_transitions: [],
    livelock_detected?: false,
    livelocks: [],
    deadlocks: [],
    unbounded_places: [],
    reachable_markings_count: 0,
    terminal_markings: [],
    violations: [],
    details: %{}
  ]

  @type t :: %__MODULE__{
          sound?: boolean(),
          definition_3_3_valid?: boolean(),
          one_safe?: boolean(),
          option_to_complete?: boolean(),
          proper_completion?: boolean(),
          no_dead_transitions?: boolean(),
          dead_transitions: [String.t()],
          livelock_detected?: boolean(),
          livelocks: [list()],
          deadlocks: [map()],
          unbounded_places: [String.t()],
          reachable_markings_count: non_neg_integer(),
          terminal_markings: [map()],
          violations: [String.t()],
          details: map()
        }
end

defmodule Ex4pmEngine.WorkflowNet do
  @moduledoc """
  Formal Workflow Net (WF-net) model implementing Definition 3.3 structural rules
  and 1-safe bounded reachability soundness verification.
  """

  alias Ex4pm.Refusal
  alias Ex4pmEngine.WorkflowNet.{Arc, Place, SoundnessReport, Transition}

  @enforce_keys [:places, :transitions, :arcs, :source_place, :sink_place]
  defstruct [
    :id,
    :places,
    :transitions,
    :arcs,
    :source_place,
    :sink_place,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          places: %{optional(String.t()) => Place.t()},
          transitions: %{optional(String.t()) => Transition.t()},
          arcs: [Arc.t()],
          source_place: String.t(),
          sink_place: String.t(),
          metadata: map()
        }

  @doc "Constructs and structurally validates a Workflow Net."
  def new(places, transitions, arcs, opts \\ []) do
    id = Keyword.get(opts, :id, "wf_net_#{System.unique_integer([:positive])}")
    metadata = Keyword.get(opts, :metadata, %{})
    source_opt = Keyword.get(opts, :source_place)
    sink_opt = Keyword.get(opts, :sink_place)

    with {:ok, norm_places} <- normalize_places(places),
         {:ok, norm_transitions} <- normalize_transitions(transitions),
         {:ok, norm_arcs} <- normalize_arcs(arcs, norm_places, norm_transitions),
         {:ok, source_place, sink_place} <-
           determine_terminals(norm_places, norm_arcs, source_opt, sink_opt) do
      net = %__MODULE__{
        id: to_string(id),
        places: norm_places,
        transitions: norm_transitions,
        arcs: norm_arcs,
        source_place: source_place,
        sink_place: sink_place,
        metadata: metadata
      }

      if Keyword.get(opts, :validate_structure, true) do
        with :ok <- validate_structure(net) do
          {:ok, net}
        end
      else
        {:ok, net}
      end
    end
  end

  @doc """
  Verifies Definition 3.3 formal WF-net structural rules:
  1. Exactly one dedicated source place i with indegree 0.
  2. Exactly one dedicated sink place o with outdegree 0.
  3. Every node (place and transition) is on a path from i to o.
  """
  def validate_structure(%__MODULE__{} = net) do
    places_ids = Map.keys(net.places) |> MapSet.new()
    transitions_ids = Map.keys(net.transitions) |> MapSet.new()
    all_nodes = MapSet.union(places_ids, transitions_ids)

    # Compute incoming and outgoing for all places
    place_incoming =
      Enum.reduce(net.arcs, %{}, fn arc, acc ->
        if MapSet.member?(places_ids, arc.target) do
          Map.update(acc, arc.target, 1, &(&1 + 1))
        else
          acc
        end
      end)

    place_outgoing =
      Enum.reduce(net.arcs, %{}, fn arc, acc ->
        if MapSet.member?(places_ids, arc.source) do
          Map.update(acc, arc.source, 1, &(&1 + 1))
        else
          acc
        end
      end)

    sources = Enum.filter(places_ids, fn p -> Map.get(place_incoming, p, 0) == 0 end)
    sinks = Enum.filter(places_ids, fn p -> Map.get(place_outgoing, p, 0) == 0 end)

    cond do
      length(sources) != 1 ->
        {:error,
         Refusal.new(
           :invalid_workflow_net_structure,
           "WF-Net must have exactly one source place with indegree 0",
           details: %{sources: sources, expected: 1}
         )}

      length(sinks) != 1 ->
        {:error,
         Refusal.new(
           :invalid_workflow_net_structure,
           "WF-Net must have exactly one sink place with outdegree 0",
           details: %{sinks: sinks, expected: 1}
         )}

      hd(sources) != net.source_place ->
        {:error,
         Refusal.new(
           :invalid_workflow_net_structure,
           "WF-Net configured source place does not match structural source place",
           details: %{configured: net.source_place, structural: hd(sources)}
         )}

      hd(sinks) != net.sink_place ->
        {:error,
         Refusal.new(
           :invalid_workflow_net_structure,
           "WF-Net configured sink place does not match structural sink place",
           details: %{configured: net.sink_place, structural: hd(sinks)}
         )}

      true ->
        # Check every node is on a path from source to sink
        forward_adj = Enum.group_by(net.arcs, & &1.source, & &1.target)
        backward_adj = Enum.group_by(net.arcs, & &1.target, & &1.source)

        reachable_from_source =
          bfs_reachable([net.source_place], forward_adj, MapSet.new([net.source_place]))

        can_reach_sink =
          bfs_reachable([net.sink_place], backward_adj, MapSet.new([net.sink_place]))

        unreachable_from_source =
          MapSet.difference(all_nodes, reachable_from_source) |> MapSet.to_list()

        cannot_reach_sink = MapSet.difference(all_nodes, can_reach_sink) |> MapSet.to_list()

        if unreachable_from_source != [] or cannot_reach_sink != [] do
          {:error,
           Refusal.new(
             :invalid_workflow_net_structure,
             "Every node in WF-net must be on a directed path from source to sink",
             details: %{
               unreachable_from_source: unreachable_from_source,
               cannot_reach_sink: cannot_reach_sink
             }
           )}
        else
          :ok
        end
    end
  end

  @doc """
  Verifies Soundness of the Workflow Net:
  - 1-Safe: No place holds > 1 tokens in any reachable marking.
  - Option to complete: From every reachable marking, the final marking [sink: 1] is reachable.
  - Proper completion: Whenever sink place has a token, it is the sole token in the marking.
  - No dead transitions: Every transition is enabled in at least one reachable marking.
  - Livelock detection: Detects terminal strongly connected components or cycles that cannot reach sink.
  """
  def verify_soundness(%__MODULE__{} = net, opts \\ []) do
    max_markings = Keyword.get(opts, :max_markings, 10_000)
    initial_marking = %{net.source_place => 1}
    target_marking = %{net.sink_place => 1}

    # Pre-index preset (input places) and postset (output places) for each transition
    preset =
      Enum.reduce(net.arcs, %{}, fn %Arc{source: s, target: t, weight: w}, acc ->
        if Map.has_key?(net.transitions, t) do
          Map.update(acc, t, %{s => w}, &Map.put(&1, s, w))
        else
          acc
        end
      end)

    postset =
      Enum.reduce(net.arcs, %{}, fn %Arc{source: t, target: p, weight: w}, acc ->
        if Map.has_key?(net.transitions, t) do
          Map.update(acc, t, %{p => w}, &Map.put(&1, p, w))
        else
          acc
        end
      end)

    # State space exploration
    state = explore_reachability(net, initial_marking, preset, postset, max_markings)

    # 1. Check 1-safety
    one_safe? = state.unbounded_places == []

    # 2. Check Proper completion: if sink has token, is marking exactly target_marking?
    improper_markings =
      Enum.filter(state.visited, fn marking ->
        Map.get(marking, net.sink_place, 0) > 0 and marking != target_marking
      end)

    proper_completion? = improper_markings == []

    # 3. Check No dead transitions: all transitions fired at least once
    all_transition_ids = Map.keys(net.transitions) |> MapSet.new()

    dead_transitions =
      MapSet.difference(all_transition_ids, state.fired_transitions) |> MapSet.to_list()

    no_dead_transitions? = dead_transitions == []

    # 4. Check Option to complete and Livelock/Deadlock detection
    # Compute reverse reachability from target_marking in the state graph
    leads_to_completion = compute_can_reach_target(state.adj, target_marking)

    cannot_complete_markings =
      Enum.reject(state.visited, fn m -> MapSet.member?(leads_to_completion, m) end)

    option_to_complete? = cannot_complete_markings == []

    # Deadlocks are non-terminal markings with outdegree 0 in state graph
    deadlocks =
      Enum.filter(state.visited, fn m ->
        m != target_marking and Map.get(state.adj, m, []) == []
      end)

    # Livelocks are SCCs / cycles in cannot_complete_markings
    livelocks = find_livelock_cycles(state.adj, cannot_complete_markings)
    livelock_detected? = livelocks != [] or (cannot_complete_markings != [] and deadlocks == [])

    violations = []

    violations =
      if not one_safe?,
        do: ["1-safety violated in places: #{inspect(state.unbounded_places)}" | violations],
        else: violations

    violations =
      if not proper_completion?,
        do: ["Proper completion violated: non-empty markings contain sink token" | violations],
        else: violations

    violations =
      if not no_dead_transitions?,
        do: ["Dead transitions detected: #{inspect(dead_transitions)}" | violations],
        else: violations

    violations =
      if not option_to_complete?,
        do: [
          "Option to complete violated: markings cannot reach target marking [#{net.sink_place}: 1]"
          | violations
        ],
        else: violations

    violations =
      if livelock_detected?,
        do: ["Livelock detected: reachability cycles trapped without completion" | violations],
        else: violations

    violations =
      if deadlocks != [],
        do: [
          "Deadlocks detected: #{length(deadlocks)} non-terminal deadlock markings" | violations
        ],
        else: violations

    sound? =
      one_safe? and proper_completion? and no_dead_transitions? and option_to_complete? and
        not livelock_detected? and deadlocks == []

    report = %SoundnessReport{
      sound?: sound?,
      definition_3_3_valid?: true,
      one_safe?: one_safe?,
      option_to_complete?: option_to_complete?,
      proper_completion?: proper_completion?,
      no_dead_transitions?: no_dead_transitions?,
      dead_transitions: dead_transitions,
      livelock_detected?: livelock_detected?,
      livelocks: livelocks,
      deadlocks: deadlocks,
      unbounded_places: state.unbounded_places,
      reachable_markings_count: length(state.visited),
      terminal_markings: Enum.filter(state.visited, &(&1 == target_marking)),
      violations: Enum.reverse(violations),
      details: %{
        fired_transition_count: MapSet.size(state.fired_transitions),
        total_transitions: map_size(net.transitions),
        improper_markings_count: length(improper_markings)
      }
    }

    if sound? do
      {:ok, report}
    else
      {:error, report}
    end
  end

  @doc "Returns enabled transitions for a given marking."
  def enabled_transitions(%__MODULE__{} = net, marking) when is_map(marking) do
    Enum.filter(net.transitions, fn {t_id, _t} ->
      transition_enabled?(net, t_id, marking)
    end)
    |> Enum.map(&elem(&1, 0))
  end

  @doc "Fires a transition from a marking, returning the new marking."
  def fire(%__MODULE__{} = net, marking, transition_id) when is_map(marking) do
    if transition_enabled?(net, transition_id, marking) do
      # Remove preset tokens
      marking_after_consume =
        Enum.reduce(net.arcs, marking, fn
          %Arc{source: p, target: ^transition_id, weight: w}, acc ->
            curr = Map.get(acc, p, 0)
            if curr <= w, do: Map.delete(acc, p), else: Map.put(acc, p, curr - w)

          _arc, acc ->
            acc
        end)

      # Add postset tokens
      new_marking =
        Enum.reduce(net.arcs, marking_after_consume, fn
          %Arc{source: ^transition_id, target: p, weight: w}, acc ->
            Map.update(acc, p, w, &(&1 + w))

          _arc, acc ->
            acc
        end)

      {:ok, clean_marking(new_marking)}
    else
      {:error,
       Refusal.new(:transition_not_enabled, "Transition is not enabled in marking",
         details: %{transition: transition_id, marking: marking}
       )}
    end
  end

  @doc "Simulates valid firing traces from source to sink up to max_depth and max_traces."
  def simulate_traces(%__MODULE__{} = net, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 20)
    max_traces = Keyword.get(opts, :max_traces, 100)
    initial_marking = %{net.source_place => 1}
    target_marking = %{net.sink_place => 1}

    traces =
      do_simulate_traces(
        net,
        initial_marking,
        target_marking,
        [],
        max_depth,
        max_traces,
        MapSet.new()
      )

    {:ok, Enum.take(traces, max_traces)}
  end

  # Helpers

  defp do_simulate_traces(
         _net,
         target_marking,
         target_marking,
         path,
         _depth,
         _max,
         _visited_states
       ) do
    [Enum.reverse(path)]
  end

  defp do_simulate_traces(_net, _marking, _target_marking, _path, depth, _max, _visited_states)
       when depth <= 0 do
    []
  end

  defp do_simulate_traces(net, marking, target_marking, path, depth, max, visited_states) do
    if MapSet.member?(visited_states, marking) do
      []
    else
      new_visited = MapSet.put(visited_states, marking)
      enabled = enabled_transitions(net, marking)

      Enum.flat_map(enabled, fn t_id ->
        t = Map.fetch!(net.transitions, t_id)
        step_label = if t.silent?, do: nil, else: t.label || t.id
        new_path = if step_label, do: [step_label | path], else: path

        case fire(net, marking, t_id) do
          {:ok, next_marking} ->
            do_simulate_traces(
              net,
              next_marking,
              target_marking,
              new_path,
              depth - 1,
              max,
              new_visited
            )

          _ ->
            []
        end
      end)
    end
  end

  defp transition_enabled?(net, transition_id, marking) do
    in_arcs = Enum.filter(net.arcs, &(&1.target == transition_id))

    Enum.all?(in_arcs, fn %Arc{source: p, weight: w} ->
      Map.get(marking, p, 0) >= w
    end)
  end

  defp explore_reachability(net, initial_marking, preset, postset, max_markings) do
    queue = :queue.from_list([initial_marking])
    visited = MapSet.new([initial_marking])
    adj = %{}
    fired_transitions = MapSet.new()
    unbounded_places = MapSet.new()

    loop_explore(
      queue,
      visited,
      adj,
      fired_transitions,
      unbounded_places,
      preset,
      postset,
      net,
      max_markings
    )
  end

  defp loop_explore(
         queue,
         visited,
         adj,
         fired_transitions,
         unbounded,
         preset,
         postset,
         net,
         max_markings
       ) do
    case :queue.out(queue) do
      {:empty, _} ->
        %{
          visited: MapSet.to_list(visited),
          adj: adj,
          fired_transitions: fired_transitions,
          unbounded_places: MapSet.to_list(unbounded)
        }

      {{:value, marking}, rest_queue} ->
        # Check 1-safety of current marking
        current_unbounded =
          marking
          |> Enum.filter(fn {_p, count} -> count > 1 end)
          |> Enum.map(&elem(&1, 0))

        new_unbounded = Enum.reduce(current_unbounded, unbounded, &MapSet.put(&2, &1))

        # Find enabled transitions
        enabled =
          Enum.filter(preset, fn {_t_id, in_places} ->
            Enum.all?(in_places, fn {p, w} -> Map.get(marking, p, 0) >= w end)
          end)

        {next_q, next_visited, next_adj, next_fired} =
          Enum.reduce(enabled, {rest_queue, visited, adj, fired_transitions}, fn {t_id, in_places},
                                                                                 {q_acc, v_acc,
                                                                                  adj_acc,
                                                                                  f_acc} ->
            out_places = Map.get(postset, t_id, %{})

            # Compute next marking
            consumed =
              Enum.reduce(in_places, marking, fn {p, w}, acc ->
                curr = Map.get(acc, p, 0)
                if curr <= w, do: Map.delete(acc, p), else: Map.put(acc, p, curr - w)
              end)

            produced =
              Enum.reduce(out_places, consumed, fn {p, w}, acc ->
                Map.update(acc, p, w, &(&1 + w))
              end)

            next_m = clean_marking(produced)
            f_updated = MapSet.put(f_acc, t_id)
            adj_updated = Map.update(adj_acc, marking, [next_m], fn succs -> [next_m | succs] end)

            if MapSet.member?(v_acc, next_m) or MapSet.size(v_acc) >= max_markings do
              {q_acc, v_acc, adj_updated, f_updated}
            else
              {:queue.in(next_m, q_acc), MapSet.put(v_acc, next_m), adj_updated, f_updated}
            end
          end)

        loop_explore(
          next_q,
          next_visited,
          next_adj,
          next_fired,
          new_unbounded,
          preset,
          postset,
          net,
          max_markings
        )
    end
  end

  defp clean_marking(marking) do
    marking
    |> Enum.reject(fn {_k, v} -> v <= 0 end)
    |> Map.new()
  end

  defp compute_can_reach_target(adj, target_marking) do
    # Reverse adjacency
    rev_adj =
      Enum.reduce(adj, %{}, fn {src, targets}, acc ->
        Enum.reduce(targets, acc, fn tgt, inner ->
          Map.update(inner, tgt, [src], &[src | &1])
        end)
      end)

    bfs_reachable([target_marking], rev_adj, MapSet.new([target_marking]))
  end

  defp find_livelock_cycles(adj, trapped_markings) do
    trapped_set = MapSet.new(trapped_markings)

    # Detect cycles purely within trapped markings
    Enum.reduce(trapped_markings, [], fn m, acc ->
      if has_cycle?(m, adj, trapped_set, [m], MapSet.new([m])) do
        [[m] | acc]
      else
        acc
      end
    end)
    |> Enum.uniq()
  end

  defp has_cycle?(current, adj, subset, path, visited) do
    nexts = Map.get(adj, current, []) |> Enum.filter(&MapSet.member?(subset, &1))

    Enum.any?(nexts, fn next ->
      if MapSet.member?(visited, next) do
        true
      else
        has_cycle?(next, adj, subset, [next | path], MapSet.put(visited, next))
      end
    end)
  end

  defp bfs_reachable([], _adj, visited), do: visited

  defp bfs_reachable([curr | rest], adj, visited) do
    neighbors = Map.get(adj, curr, []) |> Enum.reject(&MapSet.member?(visited, &1))
    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    bfs_reachable(rest ++ neighbors, adj, new_visited)
  end

  defp normalize_places(places) when is_list(places) do
    places
    |> Enum.reduce_while({:ok, %{}}, fn
      %Place{id: id} = p, {:ok, acc} ->
        {:cont, {:ok, Map.put(acc, to_string(id), %{p | id: to_string(id)})}}

      id, {:ok, acc} when is_binary(id) or is_atom(id) ->
        id_str = to_string(id)
        {:cont, {:ok, Map.put(acc, id_str, %Place{id: id_str})}}

      map, {:ok, acc} when is_map(map) ->
        id = value(map, [:id, "id"])

        if is_nil(id),
          do:
            {:halt, {:error, Refusal.new(:missing_place_id, "Place is missing id", subject: map)}},
          else:
            {:cont,
             {:ok,
              Map.put(acc, to_string(id), %Place{
                id: to_string(id),
                name: value(map, [:name, "name"])
              })}}

      other, _acc ->
        {:halt,
         {:error, Refusal.new(:invalid_places, "Invalid place definition", subject: other)}}
    end)
  end

  defp normalize_places(map) when is_map(map) do
    normalize_places(Map.values(map))
  end

  defp normalize_places(other),
    do: {:error, Refusal.new(:invalid_places, "Places must be a list or map", subject: other)}

  defp normalize_transitions(transitions) when is_list(transitions) do
    transitions
    |> Enum.reduce_while({:ok, %{}}, fn
      %Transition{id: id} = t, {:ok, acc} ->
        {:cont, {:ok, Map.put(acc, to_string(id), %{t | id: to_string(id)})}}

      id, {:ok, acc} when is_binary(id) or is_atom(id) ->
        id_str = to_string(id)
        {:cont, {:ok, Map.put(acc, id_str, %Transition{id: id_str, label: id_str})}}

      map, {:ok, acc} when is_map(map) ->
        id = value(map, [:id, "id"])

        if is_nil(id) do
          {:halt,
           {:error, Refusal.new(:missing_transition_id, "Transition is missing id", subject: map)}}
        else
          id_str = to_string(id)
          label = value(map, [:label, "label"])
          silent = value(map, [:silent?, "silent?", :silent, "silent"]) || false

          {:cont,
           {:ok,
            Map.put(acc, id_str, %Transition{
              id: id_str,
              label: if(silent, do: nil, else: to_string(label || id_str)),
              silent?: silent == true
            })}}
        end

      other, _acc ->
        {:halt,
         {:error,
          Refusal.new(:invalid_transitions, "Invalid transition definition", subject: other)}}
    end)
  end

  defp normalize_transitions(map) when is_map(map) do
    normalize_transitions(Map.values(map))
  end

  defp normalize_transitions(other),
    do:
      {:error,
       Refusal.new(:invalid_transitions, "Transitions must be a list or map", subject: other)}

  defp normalize_arcs(arcs, places, transitions) when is_list(arcs) do
    all_node_ids = MapSet.union(MapSet.new(Map.keys(places)), MapSet.new(Map.keys(transitions)))

    arcs
    |> Enum.reduce_while({:ok, []}, fn
      %Arc{source: s, target: t} = a, {:ok, acc} ->
        s_str = to_string(s)
        t_str = to_string(t)

        if MapSet.member?(all_node_ids, s_str) and MapSet.member?(all_node_ids, t_str) do
          {:cont, {:ok, [%{a | source: s_str, target: t_str} | acc]}}
        else
          {:halt,
           {:error,
            Refusal.new(:invalid_arc, "Arc references unknown place or transition",
              details: %{source: s_str, target: t_str}
            )}}
        end

      {s, t}, {:ok, acc} ->
        s_str = to_string(s)
        t_str = to_string(t)

        if MapSet.member?(all_node_ids, s_str) and MapSet.member?(all_node_ids, t_str) do
          {:cont, {:ok, [%Arc{source: s_str, target: t_str} | acc]}}
        else
          {:halt,
           {:error,
            Refusal.new(:invalid_arc, "Arc references unknown place or transition",
              details: %{source: s_str, target: t_str}
            )}}
        end

      [s, t], {:ok, acc} ->
        s_str = to_string(s)
        t_str = to_string(t)

        if MapSet.member?(all_node_ids, s_str) and MapSet.member?(all_node_ids, t_str) do
          {:cont, {:ok, [%Arc{source: s_str, target: t_str} | acc]}}
        else
          {:halt,
           {:error,
            Refusal.new(:invalid_arc, "Arc references unknown place or transition",
              details: %{source: s_str, target: t_str}
            )}}
        end

      map, {:ok, acc} when is_map(map) ->
        s = value(map, [:source, "source", :from, "from"])
        t = value(map, [:target, "target", :to, "to"])
        w = value(map, [:weight, "weight"]) || 1

        if is_nil(s) or is_nil(t) do
          {:halt,
           {:error, Refusal.new(:invalid_arc, "Arc must contain source and target", subject: map)}}
        else
          s_str = to_string(s)
          t_str = to_string(t)

          if MapSet.member?(all_node_ids, s_str) and MapSet.member?(all_node_ids, t_str) do
            {:cont, {:ok, [%Arc{source: s_str, target: t_str, weight: w} | acc]}}
          else
            {:halt,
             {:error,
              Refusal.new(:invalid_arc, "Arc references unknown place or transition",
                details: %{source: s_str, target: t_str}
              )}}
          end
        end

      other, _acc ->
        {:halt,
         {:error,
          Refusal.new(:invalid_arc, "Arc must be a tuple, list, map, or struct", subject: other)}}
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      err -> err
    end
  end

  defp normalize_arcs(other, _places, _transitions),
    do: {:error, Refusal.new(:invalid_arcs, "Arcs must be a list", subject: other)}

  defp determine_terminals(places, arcs, source_opt, sink_opt) do
    places_ids = Map.keys(places) |> MapSet.new()

    place_incoming =
      Enum.reduce(arcs, %{}, fn arc, acc ->
        if MapSet.member?(places_ids, arc.target),
          do: Map.update(acc, arc.target, 1, &(&1 + 1)),
          else: acc
      end)

    place_outgoing =
      Enum.reduce(arcs, %{}, fn arc, acc ->
        if MapSet.member?(places_ids, arc.source),
          do: Map.update(acc, arc.source, 1, &(&1 + 1)),
          else: acc
      end)

    sources = Enum.filter(places_ids, fn p -> Map.get(place_incoming, p, 0) == 0 end)
    sinks = Enum.filter(places_ids, fn p -> Map.get(place_outgoing, p, 0) == 0 end)

    source =
      cond do
        source_opt && MapSet.member?(places_ids, to_string(source_opt)) -> to_string(source_opt)
        length(sources) == 1 -> hd(sources)
        true -> nil
      end

    sink =
      cond do
        sink_opt && MapSet.member?(places_ids, to_string(sink_opt)) -> to_string(sink_opt)
        length(sinks) == 1 -> hd(sinks)
        true -> nil
      end

    if is_nil(source) or is_nil(sink) do
      {:error,
       Refusal.new(
         :invalid_workflow_net_structure,
         "Could not determine unique source and sink places (Def 3.3 violation)",
         details: %{sources: sources, sinks: sinks, source_opt: source_opt, sink_opt: sink_opt}
       )}
    else
      {:ok, source, sink}
    end
  end

  defp value(map, keys), do: Enum.find_value(keys, &Map.get(map, &1))
end

defmodule Ex4pm.Engine.WorkflowNet do
  @moduledoc "Alias module for Ex4pmEngine.WorkflowNet."
  defdelegate new(places, transitions, arcs, opts \\ []), to: Ex4pmEngine.WorkflowNet
  defdelegate validate_structure(net), to: Ex4pmEngine.WorkflowNet
  defdelegate verify_soundness(net, opts \\ []), to: Ex4pmEngine.WorkflowNet
  defdelegate enabled_transitions(net, marking), to: Ex4pmEngine.WorkflowNet
  defdelegate fire(net, marking, transition_id), to: Ex4pmEngine.WorkflowNet
  defdelegate simulate_traces(net, opts \\ []), to: Ex4pmEngine.WorkflowNet
end
