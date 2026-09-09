defmodule Ex4pmEngine.Cognition.CostLaw do
  @moduledoc """
  AutoSystems Process Cost Law evaluator.
  Computes operational execution costs as a multi-factor function:
  `cost = f(delay_ms, risk_factor, compute_units, error_penalty)`.
  """

  @doc """
  Calculates the total evaluated cost of an execution trace or model path.
  Opts:
  - `:delay_rate` (default: 0.001 per ms)
  - `:compute_rate` (default: 0.05 per unit)
  - `:risk_multiplier` (default: 1.5)
  - `:error_penalty` (default: 100.0)
  """
  def evaluate_trace(trace_metadata, opts \\ []) when is_map(trace_metadata) do
    duration_ms = Map.get(trace_metadata, :duration_ms, 0)
    compute_units = Map.get(trace_metadata, :compute_units, 1)
    risk_factor = Map.get(trace_metadata, :risk_factor, 1.0)
    errors_count = Map.get(trace_metadata, :errors_count, 0)

    delay_rate = Keyword.get(opts, :delay_rate, 0.001)
    compute_rate = Keyword.get(opts, :compute_rate, 0.05)
    risk_multiplier = Keyword.get(opts, :risk_multiplier, 1.5)
    error_penalty = Keyword.get(opts, :error_penalty, 100.0)

    base_cost = duration_ms * delay_rate + compute_units * compute_rate
    risk_adjusted = base_cost * (1.0 + (risk_factor - 1.0) * risk_multiplier)
    penalty = errors_count * error_penalty

    total = Float.round(risk_adjusted + penalty, 4)

    %{
      total_cost: total,
      base_cost: Float.round(base_cost, 4),
      delay_component: Float.round(duration_ms * delay_rate, 4),
      compute_component: Float.round(compute_units * compute_rate, 4),
      risk_multiplier_applied: risk_multiplier,
      penalty_cost: penalty
    }
  end
end
