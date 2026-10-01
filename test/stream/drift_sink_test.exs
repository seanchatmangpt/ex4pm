defmodule Ex4pm.Stream.DriftSinkTest do
  @moduledoc "Real wasm4pm statistics (ks_statistic/ks_critical_value/ewma/forecast); no mocks."
  use ExUnit.Case, async: false

  alias Ex4pm.Stream.DriftSink

  defp feed(pid, sensor, values) do
    values
    |> Enum.with_index()
    |> Enum.map(fn {v, i} -> DriftSink.observe(pid, {v, i, sensor}) end)
  end

  defp collector do
    {:ok, agent} = Agent.start_link(fn -> [] end)
    {agent, fn msg -> Agent.update(agent, &[msg | &1]) end}
  end

  defp noise(n, base), do: for(i <- 0..(n - 1), do: base + rem(i * 7, 5) * 0.1)

  test "flags an injected mean shift and forwards {:drift_detected, report}" do
    {agent, forward} = collector()
    {:ok, pid} = DriftSink.start_link(window: 20, forward: forward)

    results = feed(pid, "s1", noise(20, 10.0) ++ noise(20, 50.0))

    assert {:ok, {:drift_detected, report}} = List.last(results)
    assert report.ks_statistic > report.ks_critical_value
    assert report.drift
    assert report.standing == :alive
    assert is_list(report.ewma) and length(report.ewma) == 20
    assert report.actuation == :none
    assert [{:drift_detected, ^report}] = Agent.get(agent, & &1)
  end

  test "stays quiet on stationary data" do
    {agent, forward} = collector()
    {:ok, pid} = DriftSink.start_link(window: 20, forward: forward)

    results = feed(pid, "s1", noise(20, 10.0) ++ noise(20, 10.0) ++ noise(20, 10.0))

    assert {:ok, {:stationary, %{drift: false}}} = List.last(results)
    assert Agent.get(agent, & &1) == []
  end

  test "on_drift callback can trigger the repair reactor; Broadway message contract holds" do
    edges = [%{from: "a", to: "b"}, %{from: "b", to: "c"}]
    test_pid = self()

    on_drift = fn report ->
      {:ok, repair} =
        Reactor.run(Ex4pmEngine.Reactors.FerroplanRepairReactor, %{
          model_edges: edges,
          traces: nil,
          deviation: %{trace: ["a", "c"]},
          goal: nil,
          engine_opts: nil
        })

      send(test_pid, {:repair, report.sensor_id, repair.status})
      repair
    end

    {:ok, pid} = DriftSink.start_link(window: 20, on_drift: on_drift)

    msgs =
      (noise(20, 1.0) ++ noise(20, 9.0))
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        %Broadway.Message{data: {v, i, "s9"}, acknowledger: {Broadway.NoopAcknowledger, nil, nil}}
      end)

    assert length(DriftSink.handle_batch(msgs, %{sink_state: pid})) == 40
    assert_receive {:repair, "s9", :proposed}, 30_000
    assert [%{drift: true, repair: %{status: :proposed}}] = DriftSink.reports(pid)
  end
end
