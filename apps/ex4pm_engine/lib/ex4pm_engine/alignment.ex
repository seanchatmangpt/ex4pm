defmodule Ex4pmEngine.Alignment do
  @moduledoc """
  A* Cost-Based Optimal Trace Alignment Engine.
  Faithful BEAM realization of Van der Aalst, Adriansyah, and Dongen (2012).

  Finds an optimal alignment γ ∈ Γ between an observed trace σ and a Workflow Net N,
  minimizing the total cost of non-synchronous moves:
  - Synchronous move (a, a): cost = 0.0
  - Log-only move (a, ≫): cost = 1.0 (unadmitted/anomalous action performed by actor)
  - Model-only move (≫, a): cost = 1.0 (required transition skipped by actor)

  Calculates exact Alignment-Based Fitness:
  fitness(σ, N) = 1.0 - (Cost(γ) / Cost_max(σ, N))
  """

  defmodule Move do
    @enforce_keys [:type, :cost]
    defstruct [:type, :log_activity, :model_transition, :cost]
  end

  defmodule Result do
    @enforce_keys [
      :moves,
      :total_cost,
      :fitness,
      :trace_length,
      :model_moves_count,
      :log_moves_count,
      :sync_moves_count
    ]
    defstruct [
      :moves,
      :total_cost,
      :fitness,
      :trace_length,
      :model_moves_count,
      :log_moves_count,
      :sync_moves_count
    ]
  end

  @doc """
  Computes the optimal alignment between `trace` (list of activity strings)
  and a Petri Net / Workflow Net defined by `{transitions, initial_marking, final_marking}`.

  `transitions` is a map of `%{trans_name => %{inputs: [places], outputs: [places], label: String.t()}}`.
  """
  def align_trace(trace, net_spec, opts \\ []) when is_list(trace) and is_map(net_spec) do
    transitions = Map.fetch!(net_spec, :transitions)
    initial_marking = Map.get(net_spec, :initial_marking, ["p_in"]) |> Enum.sort()
    final_marking = Map.get(net_spec, :final_marking, ["p_out"]) |> Enum.sort()
    max_depth = Keyword.get(opts, :max_depth, 100)

    trace_len = length(trace)

    # A* Search: state = {trace_index, current_marking}
    # Priority Queue ordered by f(n) = g(n) + h(n)
    # g(n): accumulated move cost
    # h(n): heuristic remaining distance (remaining trace elements + remaining places to final marking)
    initial_state = {0, initial_marking}
    h_0 = trace_len + length(initial_marking -- final_marking)

    # Using sorted list / priority queue
    queue = [{h_0, 0.0, initial_state, []}]
    visited = MapSet.new()

    case a_star_search(queue, visited, trace, transitions, final_marking, max_depth) do
      {:ok, moves, cost} ->
        reversed_moves = Enum.reverse(moves)
        sync_count = Enum.count(reversed_moves, &(&1.type == :sync))
        log_count = Enum.count(reversed_moves, &(&1.type == :log_only))
        model_count = Enum.count(reversed_moves, &(&1.type == :model_only))

        worst_case_cost = trace_len * 1.0 + max(1, map_size(transitions) * 0.5)
        fitness = max(0.0, Float.round(1.0 - cost / worst_case_cost, 4))

        {:ok,
         %Result{
           moves: reversed_moves,
           total_cost: Float.round(cost, 2),
           fitness: fitness,
           trace_length: trace_len,
           sync_moves_count: sync_count,
           log_moves_count: log_count,
           model_moves_count: model_count
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp a_star_search([], _visited, _trace, _transitions, _final_marking, _max_depth) do
    {:error, :no_alignment_found}
  end

  defp a_star_search(
         [{_f, g, {idx, marking}, moves} | rest_queue],
         visited,
         trace,
         transitions,
         final_marking,
         max_depth
       ) do
    state_key = {idx, marking}

    if idx == length(trace) and marking == final_marking do
      # Target reached! Optimal alignment found.
      {:ok, moves, g}
    else
      if MapSet.member?(visited, state_key) or length(moves) >= max_depth do
        a_star_search(rest_queue, visited, trace, transitions, final_marking, max_depth)
      else
        new_visited = MapSet.put(visited, state_key)

        # Generate neighbor moves:
        # 1. Synchronous moves: enabled transition matches trace[idx]
        current_event = Enum.at(trace, idx)

        sync_neighbors =
          if current_event do
            for {t_name, t_def} <- transitions,
                t_def.label == current_event or to_string(t_name) == current_event,
                can_fire?(marking, t_def.inputs) do
              new_marking = fire_transition(marking, t_def.inputs, t_def.outputs)

              move = %Move{
                type: :sync,
                log_activity: current_event,
                model_transition: to_string(t_name),
                cost: 0.0
              }

              new_g = g + 0.0
              new_h = length(trace) - (idx + 1) + length(new_marking -- final_marking)
              {new_g + new_h, new_g, {idx + 1, new_marking}, [move | moves]}
            end
          else
            []
          end

        # 2. Log-only move: advance trace index without firing model (cost = 1.0)
        log_neighbors =
          if current_event do
            move = %Move{
              type: :log_only,
              log_activity: current_event,
              model_transition: nil,
              cost: 1.0
            }

            new_g = g + 1.0
            new_h = length(trace) - (idx + 1) + length(marking -- final_marking)
            [{new_g + new_h, new_g, {idx + 1, marking}, [move | moves]}]
          else
            []
          end

        # 3. Model-only moves: fire enabled transition without advancing trace index (cost = 1.0)
        model_neighbors =
          for {t_name, t_def} <- transitions, can_fire?(marking, t_def.inputs) do
            new_marking = fire_transition(marking, t_def.inputs, t_def.outputs)

            move = %Move{
              type: :model_only,
              log_activity: nil,
              model_transition: to_string(t_name),
              cost: 1.0
            }

            new_g = g + 1.0
            new_h = length(trace) - idx + length(new_marking -- final_marking)
            {new_g + new_h, new_g, {idx, new_marking}, [move | moves]}
          end

        all_neighbors = sync_neighbors ++ log_neighbors ++ model_neighbors

        # Insert neighbors into priority queue sorted by f(n)
        new_queue =
          (rest_queue ++ all_neighbors)
          |> Enum.sort_by(fn {f, g, _state, _moves} -> {f, g} end)

        a_star_search(new_queue, new_visited, trace, transitions, final_marking, max_depth)
      end
    end
  end

  defp can_fire?(marking, inputs) do
    Enum.all?(inputs, fn p -> p in marking end)
  end

  defp fire_transition(marking, inputs, outputs) do
    # Remove one token from each input place, add one token to each output place
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
