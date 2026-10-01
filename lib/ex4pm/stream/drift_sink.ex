defmodule Ex4pm.Stream.DriftSink do
  @moduledoc """
  Windowed drift detection over raw numeric sensor samples, computed by the
  admitted wasm4pm statistics algorithms (`ewma`, `forecast`, `ks_statistic`,
  `ks_critical_value`) through `Ex4pm.Engine.execute/3`.

  Sink contract (same as `Ex4pm.Stream.SensorSink`): the sink receives
  observations only -- `{value, timestamp, sensor_id}` readings, or
  `%Broadway.Message{data: reading}` -- and has no DO authority. The only
  outward effects are the caller-supplied `forward` / `on_drift` callbacks.

  ## Windowing

  Per sensor, the first `:window` samples freeze as the *reference* window.
  Every following `:window` samples form a tumbling *current* window that is
  compared to the reference:

    * `ks_statistic(reference, current)` and
      `ks_critical_value(n, m, ks_alpha)` -- drift iff statistic > critical;
    * `ewma(current, ewma_alpha)` and `forecast(current, forecast_alpha)` are
      attached to the report as evidence (smoothed series, next-window value).

  On drift `{:drift_detected, report}` is passed to `forward`, and to the
  optional `:on_drift` callback (e.g. a function that runs
  `Ex4pmEngine.Reactors.FerroplanRepairReactor`; its return value is stored
  under `report.repair`). A failing wasm call yields
  `{:drift_check_failed, %Ex4pm.Refusal{} | term}` to `forward`, never a raise.

  ## Options (`start_link/1`)

    * `:window` -- samples per window (default 20, minimum 2)
    * `:ks_alpha` (0.05), `:ewma_alpha` (0.3), `:forecast_alpha` (0.3)
    * `:forward` -- `(term -> any)`, default no-op
    * `:on_drift` -- `(report -> any)`, optional
    * `:engine_opts` -- extra opts merged into every `Ex4pm.Engine.execute/3` call
  """

  alias Ex4pm.Engine

  @type reading :: {number(), term(), String.t()}

  @doc "Start the windowing state (an Agent). Returns `{:ok, pid}`."
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    config = %{
      window: max(Keyword.get(opts, :window, 20), 2),
      ks_alpha: Keyword.get(opts, :ks_alpha, 0.05),
      ewma_alpha: Keyword.get(opts, :ewma_alpha, 0.3),
      forecast_alpha: Keyword.get(opts, :forecast_alpha, 0.3),
      forward: Keyword.get(opts, :forward, fn _ -> :ok end),
      on_drift: Keyword.get(opts, :on_drift),
      engine_opts: Keyword.get(opts, :engine_opts, [])
    }

    Agent.start_link(fn -> %{config: config, sensors: %{}, reports: []} end)
  end

  @doc """
  Fold one reading. Returns `{:ok, nil}` while a window is filling,
  `{:ok, {:drift_detected, report}}` on drift, `{:ok, {:stationary, report}}`
  when a completed window is within the critical value, or
  `{:error, refusal}` when a statistics call fails.
  """
  @spec observe(pid(), reading()) :: {:ok, term()} | {:error, term()}
  def observe(pid, {value, _ts, sensor_id}) when is_number(value) do
    {config, action} =
      Agent.get_and_update(pid, fn %{config: config, sensors: sensors} = state ->
        sensor = Map.get(sensors, sensor_id, %{reference: nil, current: []})
        {action, sensor} = step(sensor, value * 1.0, config.window)
        {{config, action}, %{state | sensors: Map.put(sensors, sensor_id, sensor)}}
      end)

    case action do
      :filling ->
        {:ok, nil}

      {:test, reference, current} ->
        evaluate(pid, config, sensor_id, reference, current)
    end
  end

  def observe(_pid, other) do
    {:error,
     Ex4pm.Refusal.new(:invalid_reading, "reading must be {number, timestamp, sensor_id}",
       details: %{reading: inspect(other)}
     )}
  end

  @doc "Reports (drift and stationary) produced so far, oldest first."
  @spec reports(pid()) :: [map()]
  def reports(pid), do: pid |> Agent.get(& &1.reports) |> Enum.reverse()

  @doc """
  Broadway sink-compatible handler. `context` carries `:sink_state` (the pid
  from `start_link/1`); the sink's own `:forward` / `:on_drift` options fire.
  """
  @spec handle_message(Broadway.Message.t(), %{sink_state: pid()}) :: Broadway.Message.t()
  def handle_message(%Broadway.Message{data: reading} = message, %{sink_state: pid}) do
    _ = observe(pid, reading)
    message
  end

  @doc "Batch form: windows a whole Broadway batch, preserving message order."
  @spec handle_batch([Broadway.Message.t()], %{sink_state: pid()}) :: [Broadway.Message.t()]
  def handle_batch(messages, context) when is_list(messages),
    do: Enum.map(messages, &handle_message(&1, context))

  # -- windowing -----------------------------------------------------------

  defp step(%{reference: nil, current: buf} = sensor, v, window) do
    buf = [v | buf]

    if length(buf) >= window,
      do: {:filling, %{sensor | reference: Enum.reverse(buf), current: []}},
      else: {:filling, %{sensor | current: buf}}
  end

  defp step(%{reference: ref, current: buf} = sensor, v, window) do
    buf = [v | buf]

    if length(buf) >= window,
      do: {{:test, ref, Enum.reverse(buf)}, %{sensor | current: []}},
      else: {:filling, %{sensor | current: buf}}
  end

  # -- statistics (wasm) ----------------------------------------------------

  defp evaluate(pid, config, sensor_id, reference, current) do
    n = length(reference)
    m = length(current)

    with {:ok, ks} <-
           run(config, :ks_statistic, %{sample_a: reference, sample_b: current}),
         {:ok, crit} <-
           run(config, :ks_critical_value, %{n: n, m: m, alpha: config.ks_alpha}),
         {:ok, ewma} <- run(config, :ewma, %{values: current, alpha: config.ewma_alpha}),
         {:ok, fc} <- run(config, :forecast, %{data: current, alpha: config.forecast_alpha}) do
      statistic = ks.value["ks_statistic"]
      critical = crit.value["ks_critical_value"]
      drift? = statistic > critical

      report = %{
        sensor_id: sensor_id,
        drift: drift?,
        ks_statistic: statistic,
        ks_critical_value: critical,
        ewma: ewma.value["ewma"],
        forecast: fc.value,
        window: %{reference: n, current: m},
        standing: Enum.reduce([ks, crit, ewma, fc], :alive, &Ex4pm.Standing.min(&1.standing, &2)),
        evidence: %{
          ks_statistic: ks.evidence,
          ks_critical_value: crit.evidence
        },
        actuation: :none
      }

      report = if drift?, do: maybe_repair(config, report), else: report
      Agent.update(pid, fn state -> %{state | reports: [report | state.reports]} end)

      if drift? do
        config.forward.({:drift_detected, report})
        {:ok, {:drift_detected, report}}
      else
        {:ok, {:stationary, report}}
      end
    else
      {:error, reason} = error ->
        config.forward.({:drift_check_failed, reason})
        error
    end
  end

  defp maybe_repair(%{on_drift: fun}, report) when is_function(fun, 1),
    do: Map.put(report, :repair, fun.(report))

  defp maybe_repair(_config, report), do: report

  defp run(config, algorithm, subject) do
    opts = Keyword.put(config.engine_opts, :engine, :"wasm_#{algorithm}")

    case Engine.execute(algorithm, subject, opts) do
      {:ok, %Engine.Result{value: %{"error" => _} = value}} ->
        {:error,
         Ex4pm.Refusal.new(:drift_statistic_failed, "wasm statistic returned an error",
           details: %{algorithm: algorithm, value: value}
         )}

      other ->
        other
    end
  end
end
