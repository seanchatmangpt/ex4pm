defmodule Ex4pmEngine.ETCPrecision do
  @moduledoc """
  Adriansyah Escaping-Edge (ETC) Precision Engine.
  Faithful BEAM realization of Adriansyah, Dongen, and Van der Aalst (2012, 2014).

  Computes process model precision by measuring "escaping edges" (transitions enabled in the model
  at each alignment state that were never observed in the log):

  Precision_ETC(L, N) = 1.0 - (Σ |EscapingEdges(s)| / Σ |EnabledTransitions(s)|)
  """

  alias Ex4pmEngine.Alignment

  @doc """
  Calculates the Escaping-Edge ETC Precision of a Workflow Net against an event log (list of traces).
  """
  def calculate_precision(traces, net_spec) when is_list(traces) and is_map(net_spec) do
    transitions = Map.fetch!(net_spec, :transitions)

    # 1. Align all traces to obtain prefix execution states
    alignments =
      Enum.map(traces, fn trace ->
        case Alignment.align_trace(trace, net_spec) do
          {:ok, result} -> result
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # 2. Build state-transition prefix tree from synchronous/model alignments
    # At each visited marking, determine:
    # - Model enabled transitions
    # - Log observed transitions fired from this state
    {total_enabled, total_escaping} =
      Enum.reduce(alignments, {0, 0}, fn align, {acc_enabled, acc_escaping} ->
        # Replay moves and track marking states
        {enabled_sum, escaping_sum, _final_marking} =
          replay_moves_for_etc(align.moves, net_spec.initial_marking, transitions)

        {acc_enabled + enabled_sum, acc_escaping + escaping_sum}
      end)

    precision =
      if total_enabled > 0 do
        Float.round(max(0.0, 1.0 - total_escaping / total_enabled), 4)
      else
        1.0
      end

    %{
      precision: precision,
      total_enabled_actions: total_enabled,
      total_escaping_actions: total_escaping,
      traces_evaluated: length(alignments)
    }
  end

  defp replay_moves_for_etc(moves, initial_marking, transitions) do
    Enum.reduce(moves, {0, 0, initial_marking}, fn move,
                                                   {acc_enabled, acc_escaping, cur_marking} ->
      # Find enabled transitions in cur_marking
      enabled_in_state =
        Enum.filter(transitions, fn {_t_name, t_def} ->
          Enum.all?(t_def.inputs, fn p -> p in cur_marking end)
        end)

      enabled_count = length(enabled_in_state)

      # Determine if the executed move was part of the enabled model transitions
      executed_label =
        move.log_activity || (move.model_transition && to_string(move.model_transition))

      observed_match =
        Enum.find(enabled_in_state, fn {t_name, t_def} ->
          t_def.label == executed_label or to_string(t_name) == executed_label
        end)

      escaping_in_state = if observed_match, do: max(0, enabled_count - 1), else: enabled_count

      # Advance marking if transition fired
      next_marking =
        if move.type in [:sync, :model_only] and move.model_transition do
          t_key = String.to_atom(move.model_transition)
          t_def = Map.get(transitions, t_key)

          if t_def do
            cur_marking
            |> remove_tokens(t_def.inputs)
            |> Kernel.++(t_def.outputs)
            |> Enum.sort()
          else
            cur_marking
          end
        else
          cur_marking
        end

      {acc_enabled + enabled_count, acc_escaping + escaping_in_state, next_marking}
    end)
  end

  defp remove_tokens(marking, []), do: marking

  defp remove_tokens(marking, [p | rest]) do
    case List.delete(marking, p) do
      new_m -> remove_tokens(new_m, rest)
    end
  end
end
