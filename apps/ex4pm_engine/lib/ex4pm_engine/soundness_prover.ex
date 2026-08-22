defmodule Ex4pmEngine.SoundnessProver do
  @moduledoc """
  Formal Reachability Graph & 1-Safe Soundness Prover for Workflow Nets.
  Faithful BEAM realization of Van der Aalst (1997, 2011).

  A Workflow Net N = (P, T, F, M0, Mf) is 1-safe sound iff:
  1. Option to complete: ∀ M ∈ [M0⟩, ∃ σ : M [σ⟩ Mf
  2. Proper completion: ∀ M ∈ [M0⟩, M ≥ Mf ⟹ M = Mf (no lingering unconsumed tokens)
  3. No dead transitions: ∀ t ∈ T, ∃ M ∈ [M0⟩ : M [t⟩
  4. 1-Safety: ∀ M ∈ [M0⟩, ∀ p ∈ P, M(p) ≤ 1
  """

  defmodule Report do
    @enforce_keys [
      :sound?,
      :option_to_complete?,
      :proper_completion?,
      :no_dead_transitions?,
      :one_safe?,
      :reachable_markings_count,
      :deadlocks,
      :dead_transitions
    ]
    defstruct [
      :sound?,
      :option_to_complete?,
      :proper_completion?,
      :no_dead_transitions?,
      :one_safe?,
      :reachable_markings_count,
      :deadlocks,
      :dead_transitions,
      counterexamples: []
    ]
  end

  @doc """
  Formally verifies the 1-safe soundness of a Workflow Net.
  `net_spec` is a map with `:places`, `:transitions`, `:initial_marking`, and `:final_marking`.
  """
  def verify_soundness(net_spec) when is_map(net_spec) do
    transitions = Map.fetch!(net_spec, :transitions)
    initial_marking = Map.get(net_spec, :initial_marking, ["p_in"]) |> Enum.sort()
    final_marking = Map.get(net_spec, :final_marking, ["p_out"]) |> Enum.sort()

    # 1. Compute complete reachable marking state space [M0⟩
    {reachable_markings, adjacency, fired_transitions} =
      build_reachability_graph(initial_marking, transitions)

    # 2. Check 1-safety: no marking has duplicate tokens on any place
    one_safe? =
      Enum.all?(reachable_markings, fn marking ->
        length(marking) == length(Enum.uniq(marking))
      end)

    # 3. Check Option to Complete: From every reachable marking M, is final_marking reachable?
    can_reach_final = compute_reachability_to_target(adjacency, final_marking)

    uncompletable_markings =
      Enum.reject(reachable_markings, &MapSet.member?(can_reach_final, &1))

    option_to_complete? = uncompletable_markings == []

    # 4. Check Proper Completion: Every marking containing final_marking must equal final_marking
    lingering_markings =
      Enum.filter(reachable_markings, fn marking ->
        MapSet.subset?(MapSet.new(final_marking), MapSet.new(marking)) and marking != final_marking
      end)

    proper_completion? = lingering_markings == []

    # 5. Check Dead Transitions: All transitions must fire in at least one reachable marking
    all_transition_names = Map.keys(transitions) |> MapSet.new()
    dead_transitions = MapSet.difference(all_transition_names, fired_transitions) |> MapSet.to_list()
    no_dead_transitions? = dead_transitions == []

    # 6. Deadlocks: Reachable markings with 0 outgoing transitions that are not final_marking
    deadlocks =
      Enum.filter(reachable_markings, fn m ->
        m != final_marking and Map.get(adjacency, m, []) == []
      end)

    sound? = option_to_complete? and proper_completion? and no_dead_transitions? and one_safe?

    counterexamples =
      (deadlocks |> Enum.map(&{:deadlock, &1})) ++
        (lingering_markings |> Enum.map(&{:unconsumed_tokens, &1})) ++
        (dead_transitions |> Enum.map(&{:dead_transition, &1}))

    %Report{
      sound?: sound?,
      option_to_complete?: option_to_complete?,
      proper_completion?: proper_completion?,
      no_dead_transitions?: no_dead_transitions?,
      one_safe?: one_safe?,
      reachable_markings_count: length(reachable_markings),
      deadlocks: deadlocks,
      dead_transitions: dead_transitions,
      counterexamples: counterexamples
    }
  end

  defp build_reachability_graph(initial_marking, transitions) do
    queue = :queue.from_list([initial_marking])
    visited = MapSet.new([initial_marking])

    bfs_reachability(queue, visited, %{}, MapSet.new(), transitions)
  end

  defp bfs_reachability(queue, visited, adjacency, fired_transitions, transitions) do
    if :queue.is_empty(queue) do
      {MapSet.to_list(visited), adjacency, fired_transitions}
    else
      {{:value, current_marking}, rest_q} = :queue.out(queue)

      # Find all enabled transitions in current marking
      enabled_firings =
        for {t_name, t_def} <- transitions, can_fire?(current_marking, t_def.inputs) do
          next_marking = fire_transition(current_marking, t_def.inputs, t_def.outputs)
          {t_name, next_marking}
        end

      next_markings = Enum.map(enabled_firings, &elem(&1, 1)) |> Enum.uniq()
      newly_fired = Enum.map(enabled_firings, &elem(&1, 0)) |> MapSet.new()
      updated_fired = MapSet.union(fired_transitions, newly_fired)

      updated_adj = Map.put(adjacency, current_marking, next_markings)

      unvisited = Enum.reject(next_markings, &MapSet.member?(visited, &1))

      new_q = Enum.reduce(unvisited, rest_q, fn m, q -> :queue.in(m, q) end)
      new_visited = Enum.reduce(unvisited, visited, fn m, v -> MapSet.put(v, m) end)

      bfs_reachability(new_q, new_visited, updated_adj, updated_fired, transitions)
    end
  end

  defp compute_reachability_to_target(adjacency, target_marking) do
    # Reverse BFS from target_marking
    reverse_adj =
      Enum.flat_map(adjacency, fn {src, dsts} ->
        Enum.map(dsts, fn dst -> {dst, src} end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    queue = :queue.from_list([target_marking])
    visited = MapSet.new([target_marking])

    reverse_bfs(queue, visited, reverse_adj)
  end

  defp reverse_bfs(queue, visited, reverse_adj) do
    if :queue.is_empty(queue) do
      visited
    else
      {{:value, current}, rest_q} = :queue.out(queue)
      predecessors = Map.get(reverse_adj, current, [])
      unvisited = Enum.reject(predecessors, &MapSet.member?(visited, &1))

      new_q = Enum.reduce(unvisited, rest_q, fn m, q -> :queue.in(m, q) end)
      new_visited = Enum.reduce(unvisited, visited, fn m, v -> MapSet.put(v, m) end)

      reverse_bfs(new_q, new_visited, reverse_adj)
    end
  end

  defp can_fire?(marking, inputs) do
    Enum.all?(inputs, fn p -> p in marking end)
  end

  defp fire_transition(marking, inputs, outputs) do
    marking
    |> remove_tokens(inputs)
    |> Kernel.++(outputs)
    |> Enum.sort()
  end

  defp remove_tokens(marking, []), do: marking
  defp remove_tokens(marking, [p | rest]) do
    case List.delete(marking, p) do
      new_m -> remove_tokens(new_m, rest)
    end
  end
end
