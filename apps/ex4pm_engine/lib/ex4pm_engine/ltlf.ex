defmodule Ex4pmEngine.LTLf do
  @moduledoc """
  Linear Temporal Logic over Finite Traces (LTLf) Model Checker.
  Faithful BEAM realization of De Giacomo and Vardi (2013, 2015).

  Evaluates declarative process compliance constraints over finite execution sequences:
  - `response(A, B)`: Whenever A occurs, B must eventually occur later (□(A → ◇B)).
  - `precedence(A, B)`: B cannot occur unless A has occurred previously (¬B W A).
  - `non_coexistence(A, B)`: A and B cannot both occur in the same trace (¬(◇A ∧ ◇B)).
  - `chain_response(A, B)`: Whenever A occurs, B must occur immediately in the next step (□(A → ○B)).
  - `exactly_once(A)`: Activity A must occur exactly once in the trace.
  - `absence(A)`: Activity A must never occur in the trace (□¬A).
  """

  defmodule Formula do
    @type t ::
            {:response, a :: String.t(), b :: String.t()}
            | {:precedence, a :: String.t(), b :: String.t()}
            | {:non_coexistence, a :: String.t(), b :: String.t()}
            | {:chain_response, a :: String.t(), b :: String.t()}
            | {:exactly_once, a :: String.t()}
            | {:absence, a :: String.t()}
            | {:and, [t()]}
            | {:or, [t()]}
  end

  @doc """
  Evaluates an LTLf formula or list of formulas against an observed trace.
  `trace` is a list of activity strings.
  Returns `%{satisfied?: boolean(), violations: [tuple()]}`.
  """
  def evaluate_trace(trace, formulas) when is_list(trace) and is_list(formulas) do
    violations =
      Enum.flat_map(formulas, fn formula ->
        case check_formula(trace, formula) do
          :ok -> []
          {:violation, details} -> [{formula, details}]
        end
      end)

    %{
      satisfied?: violations == [],
      total_formulas: length(formulas),
      violations_count: length(violations),
      violations: violations
    }
  end

  def evaluate_trace(trace, single_formula) when is_list(trace) and is_tuple(single_formula) do
    evaluate_trace(trace, [single_formula])
  end

  # 1. Response(A, B): Every occurrence of A must be followed by at least one B
  def check_formula(trace, {:response, a, b}) do
    indexed = Enum.with_index(trace)

    a_indices =
      Enum.filter(indexed, fn {act, _idx} -> act == a end)
      |> Enum.map(&elem(&1, 1))

    b_indices =
      Enum.filter(indexed, fn {act, _idx} -> act == b end)
      |> Enum.map(&elem(&1, 1))

    unfulfilled_a =
      Enum.filter(a_indices, fn a_idx ->
        not Enum.any?(b_indices, fn b_idx -> b_idx > a_idx end)
      end)

    if unfulfilled_a == [] do
      :ok
    else
      {:violation, {:response_unfulfilled, a, b, unfulfilled_a}}
    end
  end

  # 2. Precedence(A, B): B cannot occur before A has occurred
  def check_formula(trace, {:precedence, a, b}) do
    indexed = Enum.with_index(trace)

    first_a = Enum.find(indexed, fn {act, _idx} -> act == a end)
    first_a_idx = if first_a, do: elem(first_a, 1), else: :infinity

    premature_b =
      Enum.filter(indexed, fn {act, idx} ->
        act == b and (first_a_idx == :infinity or idx < first_a_idx)
      end)
      |> Enum.map(&elem(&1, 1))

    if premature_b == [] do
      :ok
    else
      {:violation, {:precedence_violated, a, b, premature_b}}
    end
  end

  # 3. Non-Coexistence(A, B): Both A and B cannot be present in the trace
  def check_formula(trace, {:non_coexistence, a, b}) do
    has_a? = a in trace
    has_b? = b in trace

    if has_a? and has_b? do
      {:violation, {:coexistence_forbidden, a, b}}
    else
      :ok
    end
  end

  # 4. Chain-Response(A, B): Every A must be immediately followed by B at index + 1
  def check_formula(trace, {:chain_response, a, b}) do
    indexed = Enum.with_index(trace)
    len = length(trace)

    bad_chains =
      Enum.filter(indexed, fn {act, idx} ->
        act == a and (idx + 1 >= len or Enum.at(trace, idx + 1) != b)
      end)
      |> Enum.map(&elem(&1, 1))

    if bad_chains == [] do
      :ok
    else
      {:violation, {:chain_response_broken, a, b, bad_chains}}
    end
  end

  # 5. Exactly-Once(A): Activity A occurs exactly 1 time
  def check_formula(trace, {:exactly_once, a}) do
    count = Enum.count(trace, &(&1 == a))

    if count == 1 do
      :ok
    else
      {:violation, {:frequency_violation, a, expected: 1, actual: count}}
    end
  end

  # 6. Absence(A): Activity A must never occur
  def check_formula(trace, {:absence, a}) do
    if a in trace do
      {:violation, {:forbidden_activity_present, a}}
    else
      :ok
    end
  end

  # 7. AND / OR Combinators
  def check_formula(trace, {:and, formulas}) when is_list(formulas) do
    results = Enum.map(formulas, &check_formula(trace, &1))
    failures = Enum.filter(results, &(&1 != :ok))

    if failures == [] do
      :ok
    else
      {:violation, {:conjunction_failed, failures}}
    end
  end

  def check_formula(trace, {:or, formulas}) when is_list(formulas) do
    if Enum.any?(formulas, &(check_formula(trace, &1) == :ok)) do
      :ok
    else
      {:violation, :disjunction_failed}
    end
  end
end
