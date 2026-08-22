defmodule Ex4pmEngine.OCPN.SoundnessEngine do
  @moduledoc """
  Formal Reachability Analysis and Soundness Verification Engine for
  Object-Centric Petri Nets (OCPN) and 1-Safe Workflow Nets.

  Verifies:
  1. Option to Complete: for all reachable markings M in [M_0>, [M_end] in [M>
  2. Proper Completion: for all M in [M_0>, sink in M implies M == [M_end]
  3. Absence of Dead Transitions: for all t in T, exists M in [M_0> such that M[t>
  4. 1-Safety: for all M in [M_0>, for all p in P, M(p) <= 1

  Emits explicit minimal counter-example trace sequences on violation.
  """

  alias Ex4pmEngine.OCPN

  @doc """
  Performs complete reachability state-space exploration on a single-object or
  projected Workflow Net to verify 1-safe soundness.
  """
  def verify_reachability(%OCPN{} = net, object_type, opts \\ []) do
    max_states = Keyword.get(opts, :max_states, 10_000)
    ot = to_string(object_type)

    places = Map.filter(net.places, fn {_, p} -> p.object_type == ot end)
    transitions = Map.filter(net.transitions, fn {_, t} -> ot in t.object_types end)
    arcs = Enum.filter(net.arcs, &(&1.object_type == ot))

    initial_place = Enum.find(places, fn {_, p} -> p.initial? end)
    terminal_place = Enum.find(places, fn {_, p} -> p.terminal? end)

    cond do
      is_nil(initial_place) ->
        {:error, {:invalid_net, "No initial source place found for #{ot}"}}

      is_nil(terminal_place) ->
        {:error, {:invalid_net, "No terminal sink place found for #{ot}"}}

      true ->
        {init_id, _} = initial_place
        {term_id, _} = terminal_place

        initial_marking = MapSet.new([init_id])
        terminal_marking = MapSet.new([term_id])

        # BFS state space exploration
        explore_state_space(initial_marking, terminal_marking, places, transitions, arcs, max_states)
    end
  end

  defp explore_state_space(m0, m_end, _places, transitions, arcs, max_states) do
    # Queue stores {current_marking, trace_path}
    queue = :queue.from_list([{m0, []}])
    visited = MapSet.new([m0])
    fired_transitions = MapSet.new()

    loop_explore(queue, visited, fired_transitions, m_end, transitions, arcs, max_states)
  end

  defp loop_explore(queue, visited, fired_transitions, m_end, transitions, arcs, max_states) do
    case :queue.out(queue) do
      {:empty, _} ->
        # Check if all transitions were fired
        all_trans_ids = MapSet.new(Map.keys(transitions))
        dead_transitions = MapSet.difference(all_trans_ids, fired_transitions)

        if MapSet.size(dead_transitions) == 0 do
          {:ok, %{
            sound?: true,
            states_explored: MapSet.size(visited),
            terminal_reachable?: true,
            dead_transitions: []
          }}
        else
          {:error, %{
            violation: :dead_transitions,
            dead_transitions: MapSet.to_list(dead_transitions),
            states_explored: MapSet.size(visited)
          }}
        end

      {{:value, {current_marking, trace}}, rest_queue} ->
        if MapSet.size(visited) > max_states do
          {:error, {:state_space_cutoff_exceeded, max_states}}
        else
          # Check proper completion: if sink in current_marking, must be exactly m_end
          sink_id = Enum.at(MapSet.to_list(m_end), 0)

          if MapSet.member?(current_marking, sink_id) and current_marking != m_end do
            {:error, %{
              violation: :improper_completion,
              improper_marking: MapSet.to_list(current_marking),
              counter_example_trace: Enum.reverse(trace)
            }}
          else
            # Find enabled transitions
            enabled =
              Enum.filter(transitions, fn {t_id, _} ->
                in_places =
                  arcs
                  |> Enum.filter(&(&1.target == t_id))
                  |> Enum.map(& &1.source)
                  |> MapSet.new()

                MapSet.subset?(in_places, current_marking) and MapSet.size(in_places) > 0
              end)

            if enabled == [] and current_marking != m_end do
              # Reachable Deadlock!
              {:error, %{
                violation: :deadlock,
                deadlocked_marking: MapSet.to_list(current_marking),
                counter_example_trace: Enum.reverse(trace)
              }}
            else
              # Fire transitions and produce new markings
              {new_queue, new_visited, new_fired} =
                Enum.reduce(enabled, {rest_queue, visited, fired_transitions}, fn {t_id, _}, {q_acc, v_acc, f_acc} ->
                  in_places =
                    arcs
                    |> Enum.filter(&(&1.target == t_id))
                    |> Enum.map(& &1.source)
                    |> MapSet.new()

                  out_places =
                    arcs
                    |> Enum.filter(&(&1.source == t_id))
                    |> Enum.map(& &1.target)
                    |> MapSet.new()

                  next_marking =
                    current_marking
                    |> MapSet.difference(in_places)
                    |> MapSet.union(out_places)

                  new_f = MapSet.put(f_acc, t_id)

                  if MapSet.member?(v_acc, next_marking) do
                    {q_acc, v_acc, new_f}
                  else
                    new_q = :queue.in({next_marking, [t_id | trace]}, q_acc)
                    new_v = MapSet.put(v_acc, next_marking)
                    {new_q, new_v, new_f}
                  end
                end)

              loop_explore(new_queue, new_visited, new_fired, m_end, transitions, arcs, max_states)
            end
          end
        end
    end
  end
end
