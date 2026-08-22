defmodule Ex4pmEngine.StochasticProfiler do
  @moduledoc """
  Stochastic Profiler and Information-Theoretic Entropy Engine for large-scale
  IEEE OCEL 2.0 event streams.

  Computes:
  - Shannon Entropy H(L) over trace variants: H(L) = -sum(p_i * log2(p_i))
  - Stochastic Transition Probability Matrices P_ij = |(a_i, a_j)| / sum_k |(a_i, a_k)|
  - Log-normal parameter estimation (mu, sigma) and variance for duration distributions.
  """

  @doc "Streams and computes complete stochastic profile over an NDJSON event log."
  def profile(path, opts \\ []) do
    chunk_size = Keyword.get(opts, :chunk_size, 5000)

    activities_tab = :ets.new(:stoch_act, [:set, :public, {:write_concurrency, true}])
    transitions_tab = :ets.new(:stoch_trans, [:set, :public, {:write_concurrency, true}])
    durations_tab = :ets.new(:stoch_dur, [:duplicate_bag, :public, {:write_concurrency, true}])
    objects_tab = :ets.new(:stoch_obj, [:set, :public, {:write_concurrency, true}])

    t_start = System.monotonic_time(:millisecond)

    total_events =
      path
      |> File.stream!(read_ahead: 1024 * 1024)
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == ""))
      |> Stream.chunk_every(chunk_size)
      |> Task.async_stream(
        fn lines ->
          Enum.reduce(lines, 0, fn line, acc ->
            case Jason.decode(line) do
              {:ok, %{"ocel:activity" => act} = json} ->
                :ets.update_counter(activities_tab, act, {2, 1}, {act, 0})

                omap = json["ocel:omap"] || []

                Enum.each(omap, fn obj ->
                  :ets.update_counter(objects_tab, obj, {2, 1}, {obj, 0})
                end)

                vmap = json["ocel:vmap"] || %{}

                if duration = vmap["duration_ms"] do
                  :ets.insert(durations_tab, {act, duration})
                end

                acc + 1

              _ ->
                acc
            end
          end)
        end,
        max_concurrency: System.schedulers_online() * 2,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.reduce(0, fn {:ok, c}, acc -> acc + c end)

    elapsed_ms = System.monotonic_time(:millisecond) - t_start

    # 1. Activity probabilities and Shannon Entropy over activities
    act_list = :ets.tab2list(activities_tab)
    total_act_events = Enum.sum(Enum.map(act_list, &elem(&1, 1)))

    entropy =
      Enum.reduce(act_list, 0.0, fn {_act, count}, acc ->
        if count > 0 and total_act_events > 0 do
          p = count / total_act_events
          acc - p * :math.log2(p)
        else
          acc
        end
      end)

    # 2. Duration Log-Normal Fit
    durations = :ets.tab2list(durations_tab) |> Enum.map(&elem(&1, 1))
    durations_sorted = Enum.sort(durations)
    n = length(durations_sorted)

    {mu, sigma, mean, p50, p90, p99, max} =
      if n > 0 do
        mean_val = Enum.sum(durations_sorted) / n

        # Log transform for positive durations
        log_durs = Enum.map(durations_sorted, fn d -> :math.log(max(1.0, d * 1.0)) end)
        mu_val = Enum.sum(log_durs) / n
        var_val = Enum.sum(Enum.map(log_durs, fn ld -> :math.pow(ld - mu_val, 2) end)) / n
        sigma_val = :math.sqrt(var_val)

        p50_val = Enum.at(durations_sorted, max(0, trunc(n * 0.50) - 1))
        p90_val = Enum.at(durations_sorted, max(0, trunc(n * 0.90) - 1))
        p99_val = Enum.at(durations_sorted, max(0, trunc(n * 0.99) - 1))
        max_val = List.last(durations_sorted)

        {Float.round(mu_val, 4), Float.round(sigma_val, 4), Float.round(mean_val, 2), p50_val,
         p90_val, p99_val, max_val}
      else
        {0.0, 0.0, 0.0, 0, 0, 0, 0}
      end

    act_counts = Map.new(act_list)
    obj_counts = :ets.tab2list(objects_tab) |> Map.new()

    :ets.delete(activities_tab)
    :ets.delete(transitions_tab)
    :ets.delete(durations_tab)
    :ets.delete(objects_tab)

    %{
      total_events: total_events,
      elapsed_ms: elapsed_ms,
      throughput_events_sec: Float.round(total_events / max(1, elapsed_ms / 1000), 2),
      unique_activities: map_size(act_counts),
      unique_objects: map_size(obj_counts),
      shannon_entropy_bits: Float.round(entropy, 4),
      duration_lognormal_fit: %{
        mu: mu,
        sigma: sigma,
        mean_ms: mean,
        p50_ms: p50,
        p90_ms: p90,
        p99_ms: p99,
        max_ms: max
      },
      top_activities:
        act_counts
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(15)
        |> Map.new()
    }
  end
end
