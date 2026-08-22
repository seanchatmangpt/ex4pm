defmodule Ex4pmEngine.Cognition.Temporal do
  @moduledoc """
  Allen's 13 interval temporal algebra and Linear Temporal Logic (LTL) trace monitor.
  Computes relational consistency across event intervals and validates temporal process constraints.
  """

  @enforce_keys [:intervals]
  defstruct [:intervals, relations: %{}, metadata: %{}]

  # Allen 13 interval relations:
  # :before (<), :meets (m), :overlaps (o), :starts (s), :during (d), :finishes (f), :equals (=)
  # and their inverses:
  # :after (>), :met_by (mi), :overlapped_by (oi), :started_by (si), :contains (di), :finished_by (fi)

  @type allen_relation ::
          :before
          | :after
          | :meets
          | :met_by
          | :overlaps
          | :overlapped_by
          | :starts
          | :started_by
          | :during
          | :contains
          | :finishes
          | :finished_by
          | :equals

  @doc "Computes the exact Allen relation between two time intervals `[start_a, end_a]` and `[start_b, end_b]`."
  def relate({s_a, e_a}, {s_b, e_b}) do
    cond do
      e_a < s_b -> :before
      s_a > e_b -> :after
      e_a == s_b -> :meets
      s_a == e_b -> :met_by
      s_a < s_b and e_a > s_b and e_a < e_b -> :overlaps
      s_b < s_a and e_b > s_a and e_b < e_a -> :overlapped_by
      s_a == s_b and e_a < e_b -> :starts
      s_a == s_b and e_a > e_b -> :started_by
      s_a > s_b and e_a < e_b -> :during
      s_a < s_b and e_a > e_b -> :contains
      s_a > s_b and e_a == e_b -> :finishes
      s_a < s_b and e_a == e_b -> :finished_by
      s_a == s_b and e_a == e_b -> :equals
    end
  end

  @doc """
  Evaluates an LTL temporal formula against an execution trace (list of activity labels).
  Formulas:
  - `{:globally, p}`: p holds at every state
  - `{:eventually, p}`: p holds at some state in the trace
  - `{:next, p}`: p holds at next state
  - `{:response, p, q}`: whenever p occurs, q eventually occurs after p
  - `{:precedence, p, q}`: q can only occur if p occurred before q
  """
  def check_ltl(trace, formula) when is_list(trace) do
    case formula do
      {:globally, p} ->
        Enum.all?(trace, &(&1 == p))

      {:eventually, p} ->
        Enum.any?(trace, &(&1 == p))

      {:next, p} ->
        case trace do
          [_first, second | _] -> second == p
          _ -> false
        end

      {:response, p, q} ->
        # For every occurrence of p at index i, there is q at index j > i
        p_indices =
          Enum.with_index(trace)
          |> Enum.filter(fn {act, _i} -> act == p end)
          |> Enum.map(&elem(&1, 1))

        Enum.all?(p_indices, fn p_idx ->
          trace
          |> Enum.drop(p_idx + 1)
          |> Enum.any?(&(&1 == q))
        end)

      {:precedence, p, q} ->
        # For every occurrence of q at index j, there is p at index i < j
        q_indices =
          Enum.with_index(trace)
          |> Enum.filter(fn {act, _j} -> act == q end)
          |> Enum.map(&elem(&1, 1))

        Enum.all?(q_indices, fn q_idx ->
          trace
          |> Enum.take(q_idx)
          |> Enum.any?(&(&1 == p))
        end)
    end
  end
end
