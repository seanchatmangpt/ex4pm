defmodule Ex4pmWeb.Telemetry do
  @moduledoc """
  Telemetry Metrics specification for the Ex4pm Process Intelligence Platform.
  Tracks streaming event rates, conformance fitness scores, alignment durations, and BEAM VM health.
  """
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Stream Metrics
      counter("ex4pm.stream.event.count", description: "Total count of ingested OCEL events"),
      summary("ex4pm.stream.batch.duration",
        unit: {:native, :millisecond},
        description: "Batch ingest latency"
      ),
      last_value("ex4pm.stream.throughput", description: "Current peak events per second"),

      # Conformance & Alignment Metrics
      last_value("ex4pm.conformance.fitness", description: "Global conformance fitness score"),
      summary("ex4pm.alignment.duration",
        unit: {:native, :millisecond},
        description: "A* trace alignment latency"
      ),
      counter("ex4pm.refusal.count", description: "Count of typed BRCE security refusals"),

      # BEAM VM Metrics
      last_value("vm.memory.total", unit: {:byte, :megabyte}),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.system_counts.process_count")
    ]
  end

  defp periodic_measurements do
    [
      # Periodic BEAM measurements
      {__MODULE__, :measure_beam, []}
    ]
  end

  def measure_beam do
    :telemetry.execute([:vm, :memory], %{total: :erlang.memory(:total)}, %{})

    :telemetry.execute(
      [:vm, :system_counts],
      %{process_count: :erlang.system_info(:process_count)},
      %{}
    )
  end
end
