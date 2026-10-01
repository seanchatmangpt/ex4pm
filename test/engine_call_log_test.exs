defmodule Ex4pm.Engine.CallLogTest do
  @moduledoc """
  Real bundled wasm + real ferroplan artifact; no mocks. Observes the engine
  call chokepoint through telemetry, the local tap and OCEL validation.
  """
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.{CallLog, Ferroplan, OnlineMiner}
  alias Ex4pmEngine.Wasm.Discover

  @subject %{traces: [["a", "b", "c"], ["a", "b"]]}
  @artifact Path.expand("../priv/ferroplan/ferroplan_wasm.wasm", __DIR__)

  defp fp_opts do
    digest = :crypto.hash(:sha256, File.read!(@artifact)) |> Base.encode16(case: :lower)
    [ferroplan_artifact: @artifact, ferroplan_expected_sha256: digest]
  end

  setup do
    CallLog.clear()
    id = "call-log-#{System.unique_integer([:positive])}"
    test = self()

    :telemetry.attach(
      id,
      [:ex4pm, :engine, :call, :stop],
      fn _e, m, meta, _ -> send(test, {:call_stop, m, meta}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(id) end)
    :ok
  end

  defp drain(acc \\ []) do
    receive do
      {:call_stop, m, meta} -> drain([{m, meta} | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end

  defp assert_valid(envelope) do
    assert {:ok, _} = Ex4pm.OCEL.validate_envelope(envelope)
    assert {:ok, log} = Ex4pm.OCEL.normalize(envelope)
    log
  end

  test "real wasm discover emits telemetry and a valid OCEL envelope" do
    assert {:ok, res} = Discover.execute(:discover, @subject, [])
    assert res.standing == :alive

    assert [{m, meta}] = drain()
    assert is_integer(m.duration) and m.duration > 0
    assert meta.engine == :wasm_discover and meta.operation == :discover
    assert meta.standing == :alive and meta.refusal_code == nil
    assert meta.replay_verified == true

    assert [env] = CallLog.events()
    log = assert_valid(env)
    [ev] = log.events
    assert ev.activity == "engine.wasm_discover.discover"
    assert length(ev.object_ids) == 3

    assert Enum.sort(Enum.map(Map.values(log.objects), &to_string(&1.type))) ==
             ["artifact", "engine", "run"]

    assert Ex4pm.Event.__struct__() && ev.attributes != %{}
    assert inspect(ev.attributes) =~ "alive"
    assert inspect(ev.attributes) =~ "duration_ms"
    assert inspect(ev.attributes) =~ "replay_verified"
  end

  test "real ferroplan version emits telemetry and a valid envelope" do
    assert {:ok, v} = Ferroplan.version(fp_opts())
    assert is_map(v)
    calls = drain()

    assert Enum.any?(calls, fn {_, meta} ->
             meta.engine == :ferroplan and meta.operation == "version"
           end)

    envs = CallLog.events()
    assert envs != []
    for env <- envs, do: assert_valid(env)
    assert Enum.any?(envs, fn e -> hd(e["events"])["activity"] == "engine.ferroplan.version" end)
  end

  test "refusal path logs refusal_code" do
    assert {:error, %Ex4pm.Refusal{code: code}} =
             Discover.execute(:discover, @subject, wasm_default: false)

    assert [{_, meta}] = drain()
    assert meta.standing == :refused
    assert meta.refusal_code == code
    assert [env] = CallLog.events()
    assert_valid(env)
    assert hd(env["events"])["attributes"]["refusal"] == to_string(code)
  end

  test "disabled flag (opt and config) emits nothing" do
    assert {:ok, _} = Discover.execute(:discover, @subject, call_log: false)
    assert drain() == []
    assert CallLog.events() == []

    Application.put_env(:ex4pm, :call_log, false)
    on_exit(fn -> Application.delete_env(:ex4pm, :call_log) end)
    assert {:ok, _} = Discover.execute(:discover, @subject, [])
    assert drain() == []
    assert CallLog.events() == []
  end

  test "wrapped result is bit-identical with logging on and off" do
    on = Discover.execute(:discover, @subject, [])
    off = Discover.execute(:discover, @subject, call_log: false)
    assert on == off

    fon = Ferroplan.version(fp_opts())
    foff = Ferroplan.version(Keyword.put(fp_opts(), :call_log, false))
    assert fon == foff

    assert CallLog.wrap(:x, :y, "d", fn -> {:ok, 1} end) == {:ok, 1}
    assert CallLog.wrap(:x, :y, "d", fn -> :weird end) == :weird
  end

  test "observation failure never alters or raises into the result" do
    # a dead ingest target is a typed note, not a crash
    assert {:ok, 1} =
             CallLog.wrap(:x, :y, "d", [call_log_ingest: :no_such_miner], fn -> {:ok, 1} end)

    assert {:call_log_ingest_failed, _} = CallLog.last_note()
  end

  test "concurrent calls each log exactly one valid envelope" do
    n = 12

    results =
      1..n
      |> Task.async_stream(fn _ -> Discover.execute(:discover, @subject, []) end,
        max_concurrency: n,
        timeout: 60_000
      )
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.all?(results, &match?({:ok, _}, &1))
    assert Enum.uniq(results) |> length() == 1
    assert length(drain()) == n
    envs = CallLog.events()
    assert length(envs) == n
    assert envs |> Enum.map(& &1["sequence"]) |> Enum.uniq() |> length() == n
    for env <- envs, do: assert_valid(env)
  end

  test "subscribe delivers envelopes and call_log_ingest feeds an OnlineMiner" do
    miner = start_supervised!({OnlineMiner, name: :call_log_test_miner})
    assert is_pid(miner)
    :ok = CallLog.subscribe()

    assert {:ok, _} =
             Discover.execute(:discover, @subject, call_log_ingest: :call_log_test_miner)

    assert_receive {:ex4pm_engine_call, env}, 1_000
    assert hd(env["events"])["activity"] == "engine.wasm_discover.discover"
    assert OnlineMiner.get_summary(:call_log_test_miner).total_events == 1
  end
end
