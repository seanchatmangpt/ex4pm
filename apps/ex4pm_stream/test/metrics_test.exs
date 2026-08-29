defmodule Ex4pm.Stream.MetricsTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Stream.Metrics

  setup do
    name = :"metrics_test_#{System.unique_integer([:positive])}"
    start_supervised!({Ex4pm.Stream.Metrics, name: name})
    # Real telemetry handler attachment happens asynchronously in
    # TelemetryMetricsPrometheus.Core.EventHandler's init/start_link; poll
    # until the real handler is actually attached before firing events.
    wait_until(fn ->
      :telemetry.list_handlers([:broadway, :processor, :message, :stop]) != [] and
        :telemetry.list_handlers([:broadway, :processor, :message, :exception]) != [] and
        :telemetry.list_handlers([:broadway, :batch_processor, :stop]) != []
    end)

    %{name: name}
  end

  defp wait_until(fun, attempts \\ 50) do
    cond do
      fun.() ->
        :ok

      attempts <= 0 ->
        flunk("condition never became true")

      true ->
        Process.sleep(20)
        wait_until(fun, attempts - 1)
    end
  end

  defp scrape_until(name, pattern, attempts \\ 50) do
    output = Metrics.scrape(name)

    cond do
      output =~ pattern ->
        output

      attempts <= 0 ->
        output

      true ->
        Process.sleep(20)
        scrape_until(name, pattern, attempts - 1)
    end
  end

  test "scrapes real counter output after a real [:broadway, :processor, :message, :stop] event",
       %{name: name} do
    :telemetry.execute(
      [:broadway, :processor, :message, :stop],
      %{duration: 1_000_000},
      %{}
    )

    output = scrape_until(name, "ex4pm_stream_broadway_messages_processed_count 1")

    assert output =~ "ex4pm_stream_broadway_messages_processed_count"
    assert output =~ "ex4pm_stream_broadway_messages_processed_count 1"
  end

  test "scrapes real distribution buckets after a real message.stop event", %{name: name} do
    :telemetry.execute(
      [:broadway, :processor, :message, :stop],
      %{duration: System.convert_time_unit(10, :millisecond, :native)},
      %{}
    )

    output = scrape_until(name, "ex4pm_stream_broadway_messages_duration_seconds_bucket")

    assert output =~ "ex4pm_stream_broadway_messages_duration_seconds_bucket"
    assert output =~ ~s(ex4pm_stream_broadway_messages_duration_seconds_bucket{le="0.01"} 1)
  end

  test "scrapes real counter output after a real [:broadway, :processor, :message, :exception] event",
       %{name: name} do
    :telemetry.execute(
      [:broadway, :processor, :message, :exception],
      %{duration: 1_000_000},
      %{kind: :error, reason: :boom}
    )

    output = scrape_until(name, "ex4pm_stream_broadway_messages_failed_count 1")

    assert output =~ "ex4pm_stream_broadway_messages_failed_count"
    assert output =~ "ex4pm_stream_broadway_messages_failed_count 1"
  end

  test "runs a real Broadway pipeline and observes real emitted processor.message.stop events",
       %{name: name} do
    test_pid = self()

    sink = fn event -> send(test_pid, {:sunk, event}) end

    {:ok, pid} =
      Ex4pm.Stream.Pipeline.start_link(
        name: :"broadway_metrics_test_#{System.unique_integer([:positive])}",
        sink: sink,
        events: [%Ex4pm.Event{id: "e1", activity: "a", timestamp: DateTime.utc_now()}]
      )

    on_exit(fn ->
      try do
        if Process.alive?(pid), do: Broadway.stop(pid)
      catch
        :exit, _ -> :ok
      end
    end)

    assert_receive {:sunk, %Ex4pm.Event{id: "e1"}}, 2_000

    output = scrape_until(name, "ex4pm_stream_broadway_messages_processed_count 1")
    assert output =~ "ex4pm_stream_broadway_messages_processed_count"
  end
end
