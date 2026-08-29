defmodule Ex4pm.Stream.Metrics do
  @moduledoc """
  Prometheus telemetry metrics for the `Ex4pm.Stream.Pipeline` Broadway pipeline.

  Wraps `TelemetryMetricsPrometheus.Core` over Broadway's real telemetry events
  (confirmed against the vendored `deps/broadway/lib/broadway.ex` telemetry docs):

    * `[:broadway, :processor, :message, :stop]` — emitted after each message is
      processed by `handle_message/3`; measurement `:duration` is the processing
      time in native time units.
    * `[:broadway, :processor, :message, :exception]` — emitted when
      `handle_message/3` raises.
    * `[:broadway, :batch_processor, :stop]` — emitted after a batch is handled.

  Start under a supervisor with `{Ex4pm.Stream.Metrics, name: :my_metrics}` (or no
  opts for the default name), then call `scrape/0` (or `scrape/1` with an explicit
  name) to get the real Prometheus-format text.
  """

  alias Telemetry.Metrics

  @default_name :ex4pm_stream_prometheus_metrics

  @doc "The list of real Telemetry.Metrics definitions built over Broadway's telemetry events."
  @spec metrics() :: [Metrics.t()]
  def metrics do
    [
      Metrics.counter(
        "ex4pm.stream.broadway.messages.processed.count",
        event_name: [:broadway, :processor, :message, :stop],
        description: "Count of Broadway messages processed by the ex4pm stream pipeline."
      ),
      Metrics.counter(
        "ex4pm.stream.broadway.messages.failed.count",
        event_name: [:broadway, :processor, :message, :exception],
        description: "Count of Broadway messages that raised during processing."
      ),
      Metrics.distribution(
        "ex4pm.stream.broadway.messages.duration.seconds",
        event_name: [:broadway, :processor, :message, :stop],
        measurement: :duration,
        unit: {:native, :second},
        description: "Distribution of per-message Broadway processing duration.",
        reporter_options: [buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5]]
      ),
      Metrics.counter(
        "ex4pm.stream.broadway.batches.processed.count",
        event_name: [:broadway, :batch_processor, :stop],
        description: "Count of Broadway batches processed by the ex4pm stream pipeline."
      )
    ]
  end

  @doc "Real `TelemetryMetricsPrometheus.Core` child spec, ready for a supervision tree."
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.get(opts, :name, @default_name)

    Supervisor.child_spec(
      {TelemetryMetricsPrometheus.Core, [metrics: metrics(), name: name]},
      id: {__MODULE__, name}
    )
  end

  @doc "Scrapes the default-named Prometheus reporter and returns real Prometheus-format text."
  @spec scrape() :: String.t()
  def scrape, do: scrape(@default_name)

  @doc "Scrapes the named Prometheus reporter and returns real Prometheus-format text."
  @spec scrape(atom()) :: String.t()
  def scrape(name), do: TelemetryMetricsPrometheus.Core.scrape(name)

  @doc "The default reporter name used when no explicit `:name` is given."
  @spec default_name() :: atom()
  def default_name, do: @default_name
end
