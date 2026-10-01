defmodule Ex4pm.EngineFerroplanSessionTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.Ferroplan.Sessions
  alias Ex4pm.Refusal
  alias Ex4pmEngine.Wasm.FerroplanTransport

  @artifact Path.expand("../priv/ferroplan/ferroplan_wasm.wasm", __DIR__)
  @fixtures Path.expand("support/fixtures/ferroplan", __DIR__)

  defp fixture(name), do: File.read!(Path.join(@fixtures, name))

  defp opts do
    digest = :crypto.hash(:sha256, File.read!(@artifact)) |> Base.encode16(case: :lower)
    [ferroplan_artifact: @artifact, ferroplan_expected_sha256: digest]
  end

  defp logistics do
    {:ok, id} =
      Sessions.new(fixture("logistics_domain.pddl"), fixture("logistics_p1.pddl"), opts())

    id
  end

  # Truck teleports to b without the box: the stashed plan cannot work any more.
  @drift [{"(at-veh t1 a)", false}, {"(at-veh t1 b)", true}]

  test "think, observe a plan-breaking event, repair" do
    id = logistics()
    on_exit(fn -> Sessions.free(id) end)

    assert {:ok, %{"solved" => true, "verdict" => "solved"}} = Sessions.think(id)
    assert {:ok, %{"has_plan" => true}} = Sessions.call(id, :has_plan)
    assert {:ok, %{"valid" => true}} = Sessions.plan_valid?(id)
    assert {:ok, %{"value" => [_ | _] = suffix}} = Sessions.suffix(id)

    assert {:ok, %{"value" => [_ | _]}} = Sessions.observe(id, @drift)
    assert {:ok, %{"valid" => false}} = Sessions.plan_valid?(id)

    assert {:ok, repaired} = Sessions.repair(id)
    assert repaired["trigger"] == "invalid_plan"
    assert repaired["decision"] in ["replanned_following", "replanned_full"]
    assert repaired["solution"]["solved"] == true
    assert {:ok, %{"valid" => true}} = Sessions.plan_valid?(id)
    assert {:ok, %{"value" => new_suffix}} = Sessions.suffix(id)
    assert new_suffix != suffix
  end

  test "fork is an independent session; probe does not mutate the parent" do
    id = logistics()
    on_exit(fn -> Sessions.free(id) end)
    assert {:ok, %{"solved" => true}} = Sessions.think(id)

    assert {:ok, child} = Sessions.fork(id, keep_plan: true)
    on_exit(fn -> Sessions.free(child) end)
    assert child != id
    assert {:ok, %{"has_plan" => true}} = Sessions.call(child, :has_plan)

    # diverge the child only
    assert {:ok, _} = Sessions.observe(child, @drift)
    assert {:ok, %{"valid" => false}} = Sessions.plan_valid?(child)
    assert {:ok, %{"valid" => true}} = Sessions.plan_valid?(id)

    # a plain fork drops the plan
    assert {:ok, bare} = Sessions.fork(id)
    on_exit(fn -> Sessions.free(bare) end)
    assert {:ok, %{"has_plan" => false}} = Sessions.call(bare, :has_plan)

    assert {:ok, probed} =
             Sessions.probe(id, [
               %{id: "baseline", goal: ">= (stock b box) 1"},
               %{id: "ungrounded", goal: "(at-veh t1 nowhere)"}
             ])

    assert probed["candidate_count"] == 2
    assert [%{"outcome" => _}, %{"outcome" => "refused"}] = probed["results"]
    assert {:ok, %{"valid" => true}} = Sessions.plan_valid?(id)
  end

  test "free removes the process and the guest handle is rejected" do
    id = logistics()
    pid = Ex4pm.Engine.Ferroplan.Session.whereis(id)
    assert is_pid(pid)
    assert id in Sessions.list()

    # out-of-band free in the guest: the instance now rejects the handle
    {:ok, %{handle: handle, transport: transport}} = Sessions.info(id)

    assert {:ok, %{"freed" => true}} =
             FerroplanTransport.call(transport, "session_free", %{"handle" => handle})

    assert {:error, %Refusal{code: :ferroplan_engine_error, message: msg}} =
             Sessions.plan_valid?(id)

    assert msg =~ "unknown session handle"

    # the process still tears down cleanly (guest free reports the unknown handle)
    ref = Process.monitor(pid)
    assert {:error, %Refusal{code: :ferroplan_engine_error}} = Sessions.free(id)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000
    refute Process.alive?(pid)
    refute id in Sessions.list()
    assert {:error, %Refusal{code: :ferroplan_session_not_found}} = Sessions.plan_valid?(id)
  end

  test "free on a healthy session returns freed and stops its wasm instance" do
    id = logistics()
    pid = Ex4pm.Engine.Ferroplan.Session.whereis(id)
    {:ok, %{transport: transport}} = Sessions.info(id)
    ref = Process.monitor(pid)

    assert {:ok, %{"freed" => true}} = Sessions.free(id)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000
    refute Process.alive?(transport)
    assert {:error, %Refusal{code: :ferroplan_session_not_found}} = Sessions.free(id)
  end

  test "killed wasm instance: calls refuse typed, recover/1 rebuilds from the journal" do
    id = logistics()
    on_exit(fn -> Sessions.free(id) end)

    assert {:ok, %{"solved" => true}} = Sessions.think(id)
    assert {:ok, _} = Sessions.observe(id, @drift)
    assert {:ok, %{"valid" => false}} = Sessions.plan_valid?(id)
    assert {:ok, _} = Sessions.repair(id)
    assert {:ok, %{"value" => suffix_before}} = Sessions.suffix(id)

    {:ok, %{transport: old, handle: old_handle}} = Sessions.info(id)
    ref = Process.monitor(old)
    Process.exit(old, :kill)
    assert_receive {:DOWN, ^ref, :process, ^old, _}, 5_000

    assert {:error, %Refusal{code: :ferroplan_session_instance_lost}} = Sessions.plan_valid?(id)
    assert {:ok, %{instance_lost: true}} = Sessions.info(id)

    assert {:ok, %{instance_lost: false, journal_length: n}} = Sessions.recover(id)
    assert n >= 3

    {:ok, %{transport: fresh}} = Sessions.info(id)
    assert fresh != old and Process.alive?(fresh)
    _ = old_handle

    assert {:ok, %{"valid" => true}} = Sessions.plan_valid?(id)
    assert {:ok, %{"value" => ^suffix_before}} = Sessions.suffix(id)

    assert {:ok, %{"value" => false}} =
             Sessions.call(id, :fact, %{name: "(at-veh t1 a)"}) |> unwrap_value()
  end

  defp unwrap_value({:ok, %{"value" => v}}), do: {:ok, %{"value" => v}}
  defp unwrap_value(other), do: other

  test "20 concurrent sessions are isolated" do
    ids =
      1..20
      |> Task.async_stream(fn _ -> logistics() end, max_concurrency: 20, timeout: 120_000)
      |> Enum.map(fn {:ok, id} -> id end)

    on_exit(fn -> Enum.each(ids, &Sessions.free/1) end)
    assert length(Enum.uniq(ids)) == 20

    handles = for id <- ids, do: elem(Sessions.info(id), 1).handle
    transports = for id <- ids, do: elem(Sessions.info(id), 1).transport
    # one wasm instance per session: no shared instance, hence no handle collision
    assert length(Enum.uniq(transports)) == 20
    assert length(handles) == 20

    # diverge the odd sessions only; the even ones must not see it
    results =
      ids
      |> Enum.with_index()
      |> Task.async_stream(
        fn {id, i} ->
          {:ok, %{"solved" => true}} = Sessions.think(id)
          if rem(i, 2) == 1, do: {:ok, _} = Sessions.observe(id, @drift)
          {i, Sessions.plan_valid?(id)}
        end,
        max_concurrency: 20,
        timeout: 120_000
      )
      |> Enum.map(fn {:ok, r} -> r end)

    for {i, {:ok, %{"valid" => valid}}} <- results do
      assert valid == (rem(i, 2) == 0), "session #{i} leaked state"
    end

    assert Enum.all?(ids, &(&1 in Sessions.list()))
  end

  test "unknown op is a typed refusal; bad ids too" do
    id = logistics()
    on_exit(fn -> Sessions.free(id) end)

    assert {:error, %Refusal{code: :ferroplan_session_unknown_op, details: %{supported: ops}}} =
             Sessions.call(id, :teleport, %{})

    assert length(ops) == 28
    assert {:error, %Refusal{code: :ferroplan_session_unknown_op}} = Sessions.call(id, "nope")

    assert {:error, %Refusal{code: :ferroplan_session_not_found}} =
             Sessions.call("fps_none", :valid)

    assert {:error, %Refusal{code: :ferroplan_bad_input}} = Sessions.new(1, 2)
    assert {:error, %Refusal{}} = Sessions.new("(define (domain", "(define", opts())

    assert {:error, %Refusal{code: :ferroplan_engine_error}} =
             Sessions.call(id, :set_fact, %{name: "(at-veh t1 a)"})
  end
end
