defmodule Ex4pmEngine.Cognition.Survival do
  @moduledoc """
  Survival Analysis and Remaining Useful Life (RUL) estimation for OCEL process cases.
  Implements non-parametric Kaplan-Meier survival curves and cumulative hazard estimation.
  """

  @doc """
  Estimates the survival function S(t) = P(T > t) and median remaining time from observed case durations.
  `durations_ms` is a list of completed case durations in milliseconds.
  """
  def fit_kaplan_meier(durations_ms) when is_list(durations_ms) and durations_ms != [] do
    sorted = Enum.sort(durations_ms)
    total_n = length(sorted)

    frequencies = Enum.frequencies(sorted) |> Enum.sort_by(&elem(&1, 0))

    {curve, _n_remaining} =
      Enum.reduce(frequencies, {[], total_n}, fn {time, d_i}, {acc_curve, n_i} ->
        p_survive = 1.0 - d_i / n_i
        prev_s = if acc_curve == [], do: 1.0, else: hd(acc_curve).survival_prob
        new_s = Float.round(prev_s * p_survive, 4)

        entry = %{
          time_ms: time,
          at_risk: n_i,
          events: d_i,
          survival_prob: new_s,
          cumulative_hazard: Float.round(-:math.log(max(0.0001, new_s)), 4)
        }

        {[entry | acc_curve], n_i - d_i}
      end)

    reversed_curve = Enum.reverse(curve)

    median_entry = Enum.find(reversed_curve, &(&1.survival_prob <= 0.5))
    median_time = if median_entry, do: median_entry.time_ms, else: List.last(sorted)

    %{
      sample_size: total_n,
      median_duration_ms: median_time,
      min_duration_ms: List.first(sorted),
      max_duration_ms: List.last(sorted),
      survival_curve: reversed_curve,
      curve_tuple: List.to_tuple(reversed_curve)
    }
  end

  @doc "Predicts remaining time for an in-flight case given its elapsed duration so far."
  def predict_remaining_time(survival_model, elapsed_ms) when is_map(survival_model) do
    median = survival_model.median_duration_ms
    remaining = max(0, median - elapsed_ms)

    curve_tuple =
      case survival_model do
        %{curve_tuple: t} when is_tuple(t) -> t
        %{survival_curve: list} when is_list(list) -> List.to_tuple(list)
        _ -> {}
      end

    curr_s =
      if tuple_size(curve_tuple) == 0 do
        1.0
      else
        binary_search_survival(curve_tuple, elapsed_ms, 0, tuple_size(curve_tuple) - 1)
      end

    %{
      elapsed_ms: elapsed_ms,
      expected_remaining_ms: remaining,
      survival_at_elapsed: curr_s,
      risk_of_exceeding_median?: elapsed_ms > median
    }
  end

  defp binary_search_survival(_tuple, _elapsed, low, high) when low > high, do: 1.0

  defp binary_search_survival(tuple, elapsed, low, high) do
    mid = div(low + high, 2)
    entry = elem(tuple, mid)

    cond do
      entry.time_ms == elapsed ->
        entry.survival_prob

      entry.time_ms < elapsed and
          (mid == tuple_size(tuple) - 1 or elem(tuple, mid + 1).time_ms > elapsed) ->
        entry.survival_prob

      entry.time_ms < elapsed ->
        binary_search_survival(tuple, elapsed, mid + 1, high)

      true ->
        binary_search_survival(tuple, elapsed, low, mid - 1)
    end
  end
end
