defmodule Ex4pmEngine.DAPN do
  @moduledoc """
  Data-Aware Petri Nets (DAPN) with First-Order Guard Evaluation.
  Faithful BEAM realization of Montali, Calvanese, and De Giacomo (2014, 2017).

  Transitions require both valid token markings AND satisfaction of data attribute guards:
  - Transition t = (Inputs, Outputs, Label, Guard)
  - Guard φ(vmap): evaluated over the event/case attribute dictionary (e.g. `amount > 5000`, `role == "manager"`).
  """

  defmodule Guard do
    @type op :: :eq | :neq | :gt | :gte | :lt | :lte | :in | :and | :or | :not
    @type t ::
            {:attr, key :: String.t() | atom(), op(), value :: any()}
            | {:and, [t()]}
            | {:or, [t()]}
            | {:not, t()}
            | :always_true
  end

  @doc "Evaluates a first-order guard against an attribute map."
  def evaluate_guard(:always_true, _vmap), do: true
  def evaluate_guard(nil, _vmap), do: true

  def evaluate_guard({:attr, key, op, expected}, vmap) do
    actual = Map.get(vmap, to_string(key)) || Map.get(vmap, key)

    case op do
      :eq -> actual == expected
      :neq -> actual != expected
      :gt -> is_number(actual) and is_number(expected) and actual > expected
      :gte -> is_number(actual) and is_number(expected) and actual >= expected
      :lt -> is_number(actual) and is_number(expected) and actual < expected
      :lte -> is_number(actual) and is_number(expected) and actual <= expected
      :in -> is_list(expected) and actual in expected
      _ -> false
    end
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

  @doc """
  Checks if a DAPN transition can fire given current marking and attribute dictionary.
  """
  def can_fire?(marking, inputs, guard, vmap) do
    tokens_available? = Enum.all?(inputs, fn p -> p in marking end)
    guard_satisfied? = evaluate_guard(guard, vmap)

    tokens_available? and guard_satisfied?
  end

  @doc """
  Simulates execution of a data-aware trace over a DAPN specification.
  `trace` is a list of `%{activity: String.t(), attributes: map()}` events.
  """
  def execute_dapn_trace(trace, dapn_spec) when is_list(trace) and is_map(dapn_spec) do
    transitions = Map.fetch!(dapn_spec, :transitions)
    initial_marking = Map.get(dapn_spec, :initial_marking, ["p_in"]) |> Enum.sort()
    final_marking = Map.get(dapn_spec, :final_marking, ["p_out"]) |> Enum.sort()

    Enum.reduce_while(trace, {:ok, initial_marking, []}, fn event,
                                                            {:ok, cur_marking, fired_acc} ->
      act = event.activity || event["activity"]
      attrs = event.attributes || event["attributes"] || %{}

      # Find matching transition that can fire with both tokens and data guard
      candidate =
        Enum.find(transitions, fn {_t_name, t_def} ->
          label_match? = t_def.label == act or to_string(t_def.label) == act
          guard = Map.get(t_def, :guard, :always_true)
          label_match? and can_fire?(cur_marking, t_def.inputs, guard, attrs)
        end)

      case candidate do
        {t_name, t_def} ->
          next_marking =
            cur_marking
            |> remove_tokens(t_def.inputs)
            |> Kernel.++(t_def.outputs)
            |> Enum.sort()

          {:cont, {:ok, next_marking, [{t_name, act, attrs} | fired_acc]}}

        nil ->
          {:halt, {:error, {:guard_or_control_violation, act, cur_marking, attrs}}}
      end
    end)
    |> case do
      {:ok, final_m, fired} ->
        if final_m == final_marking do
          {:ok,
           %{satisfied?: true, final_marking: final_m, fired_transitions: Enum.reverse(fired)}}
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
