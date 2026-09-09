defmodule Ex4pmEngine.Cognition.Markov do
  @moduledoc """
  Markov Chain Process Dynamics & Transition Probability Matrices.
  Models state transition probabilities and stationary distributions across process lifecycles.
  """

  @doc "Builds a first-order Markov transition probability matrix from trace sequences."
  def fit_markov_chain(traces) when is_map(traces) or is_list(traces) do
    trace_list = if is_map(traces), do: Map.values(traces), else: traces

    transitions =
      trace_list
      |> Enum.flat_map(fn events ->
        activities = Enum.map(events, fn ev -> if is_map(ev), do: ev.activity, else: ev end)

        activities
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] -> {a, b} end)
      end)
      |> Enum.frequencies()

    # Group by source state and normalize to probabilities
    grouped_by_src =
      transitions
      |> Enum.group_by(fn {{src, _dst}, _count} -> src end, fn {{_src, dst}, count} ->
        {dst, count}
      end)

    transition_matrix =
      Map.new(grouped_by_src, fn {src, dst_counts} ->
        total_out = Enum.sum(Enum.map(dst_counts, &elem(&1, 1)))

        probs =
          Map.new(dst_counts, fn {dst, count} ->
            {dst, Float.round(count / total_out, 4)}
          end)

        {src, probs}
      end)

    states = Map.keys(transition_matrix) |> Enum.sort()

    %{
      states: states,
      state_count: length(states),
      transition_matrix: transition_matrix
    }
  end

  @doc "Calculates transition probability P(next_state | current_state)."
  def transition_prob(markov_model, current_state, next_state) do
    markov_model.transition_matrix
    |> Map.get(to_string(current_state), %{})
    |> Map.get(to_string(next_state), 0.0)
  end
end
