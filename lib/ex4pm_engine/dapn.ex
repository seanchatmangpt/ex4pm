defmodule Ex4pmEngine.DAPN do
  @moduledoc """
  Data-Aware Petri Nets (DAPN) with First-Order Guard Evaluation & Cross-Step Binding Accumulation.
  Faithful BEAM realization of Montali, Calvanese, and De Giacomo (2014, 2017).

  Transitions require both valid token markings AND satisfaction of data attribute guards:
  - Transition t = (Inputs, Outputs, Label, Guard)
  - Guard φ(vmap): evaluated over the cumulative event/case attribute environment.
  - Supports cross-step variable references, diffs, sums, and relative comparisons.
  """

  defmodule Guard do
    @type op :: :eq | :neq | :gt | :gte | :lt | :lte | :in | :and | :or | :not
    @type t ::
            {:attr, key :: String.t() | atom(), op(), value :: any()}
            | {:ref, key1 :: String.t() | atom(), op(), key2 :: String.t() | atom()}
            | {:diff, key1 :: String.t() | atom(), key2 :: String.t() | atom(), op(),
               expected :: any()}
            | {:sum, keys :: [String.t() | atom()], op(), expected :: any()}
            | {:and, [t()]}
            | {:or, [t()]}
            | {:not, t()}
            | :always_true
  end

  @doc "Evaluates a first-order guard against an accumulated attribute environment map."
  def evaluate_guard(:always_true, _vmap), do: true
  def evaluate_guard(nil, _vmap), do: true

  def evaluate_guard({:attr, key, op, expected}, vmap) do
    actual = get_value(vmap, key)
    apply_op(op, actual, expected)
  end

  def evaluate_guard({:ref, key1, op, key2}, vmap) do
    val1 = get_value(vmap, key1)
    val2 = get_value(vmap, key2)
    apply_op(op, val1, val2)
  end

  def evaluate_guard({:diff, key1, key2, op, expected}, vmap) do
    val1 = get_value(vmap, key1) || 0
    val2 = get_value(vmap, key2) || 0

    if is_number(val1) and is_number(val2) do
      diff = val1 - val2
      apply_op(op, diff, expected)
    else
      false
    end
  end

  def evaluate_guard({:sum, keys, op, expected}, vmap) when is_list(keys) do
    total =
      Enum.reduce(keys, 0, fn k, acc ->
        v = get_value(vmap, k) || 0
        if is_number(v), do: acc + v, else: acc
      end)

    apply_op(op, total, expected)
  end

  def evaluate_guard({:and, subguards}, vmap) when is_list(subguards) do
    Enum.all?(subguards, &evaluate_guard(&1, vmap))
  end

  def evaluate_guard({:or, subguards}, vmap) when is_list(subguards) do
    Enum.any?(subguards, &evaluate_guard(&1, vmap))
  end

  def evaluate_guard({:not, subguard}, vmap) do
    not evaluate_guard(subguard, vmap)
  end

  defp get_value(vmap, key) do
    Map.get(vmap, to_string(key)) || Map.get(vmap, key)
  end

  defp apply_op(:eq, actual, expected), do: actual == expected
  defp apply_op(:neq, actual, expected), do: actual != expected

  defp apply_op(:gt, actual, expected),
    do: is_number(actual) and is_number(expected) and actual > expected

  defp apply_op(:gte, actual, expected),
    do: is_number(actual) and is_number(expected) and actual >= expected

  defp apply_op(:lt, actual, expected),
    do: is_number(actual) and is_number(expected) and actual < expected

  defp apply_op(:lte, actual, expected),
    do: is_number(actual) and is_number(expected) and actual <= expected

  defp apply_op(:in, actual, expected), do: is_list(expected) and actual in expected
  defp apply_op(_op, _actual, _expected), do: false

  @doc """
  Checks if a DAPN transition can fire given current marking and attribute dictionary.
  """
  def can_fire?(marking, inputs, guard, vmap) do
    tokens_available? = Enum.all?(inputs, fn p -> p in marking end)
    guard_satisfied? = evaluate_guard(guard, vmap)

    tokens_available? and guard_satisfied?
  end

  @doc """
  Simulates execution of a data-aware trace over a DAPN specification with cumulative variable propagation.
  `trace` is a list of `%{activity: String.t(), attributes: map()}` events.
  """
  def execute_dapn_trace(trace, dapn_spec, initial_env \\ %{})
      when is_list(trace) and is_map(dapn_spec) and is_map(initial_env) do
    transitions = Map.fetch!(dapn_spec, :transitions)
    initial_marking = Map.get(dapn_spec, :initial_marking, ["p_in"]) |> Enum.sort()
    final_marking = Map.get(dapn_spec, :final_marking, ["p_out"]) |> Enum.sort()

    Enum.reduce_while(trace, {:ok, initial_marking, initial_env, []}, fn event,
                                                                         {:ok, cur_marking,
                                                                          cur_env, fired_acc} ->
      act = event.activity || event["activity"]
      event_attrs = event.attributes || event["attributes"] || %{}
      accumulated_env = Map.merge(cur_env, event_attrs)

      # Find matching transition that can fire with both tokens and accumulated data guard
      candidate =
        Enum.find(transitions, fn {_t_name, t_def} ->
          label_match? = t_def.label == act or to_string(t_def.label) == act
          guard = Map.get(t_def, :guard, :always_true)
          label_match? and can_fire?(cur_marking, t_def.inputs, guard, accumulated_env)
        end)

      case candidate do
        {t_name, t_def} ->
          next_marking =
            cur_marking
            |> remove_tokens(t_def.inputs)
            |> Kernel.++(t_def.outputs)
            |> Enum.sort()

          {:cont, {:ok, next_marking, accumulated_env, [{t_name, act, event_attrs} | fired_acc]}}

        nil ->
          {:halt, {:error, {:guard_or_control_violation, act, cur_marking, accumulated_env}}}
      end
    end)
    |> case do
      {:ok, final_m, final_env, fired} ->
        if final_m == final_marking do
          {:ok,
           %{
             satisfied?: true,
             final_marking: final_m,
             final_env: final_env,
             fired_transitions: Enum.reverse(fired)
           }}
        else
          {:error, {:unconsumed_tokens_at_end, final_m}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp remove_tokens(marking, []), do: marking

  defp remove_tokens(marking, [p | rest]) do
    case List.delete(marking, p) do
      new_m -> remove_tokens(new_m, rest)
    end
  end
end
