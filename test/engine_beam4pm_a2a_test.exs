defmodule Engine.Beam4pmA2ATest do
  use ExUnit.Case, async: false

  # Real, no-mock tests exercising the real A2A wire protocol end to end:
  # real `A2A.Agent` GenServer (test/support/micro_beam4pm_a2a.ex,
  # standing in for beam4pm's real mounted BeamPM.A2AAgent the same way
  # test/support/micro_beam4pm.ex already stands in for beam4pm's real
  # AshJsonApi surface in test/engine_beam4pm_test.exs), real A2A.Plug
  # over a real Bandit HTTP server, real A2A.Client.discover/2 and
  # A2A.Client.send_message/3 calls over real HTTP/JSON-RPC.

  alias Ex4pm.Engine.Beam4pmA2A

  setup do
    {:ok, _agent_pid} = start_supervised({MicroBeam4pmA2A.Agent, []})
    port = Enum.random(20_000..29_999)
    base_url = "http://127.0.0.1:#{port}"

    {:ok, plug_pid} =
      Bandit.start_link(
        plug: MicroBeam4pmA2A.Router,
        port: port,
        ip: {127, 0, 0, 1}
      )

    on_exit(fn ->
      Process.exit(plug_pid, :normal)
    end)

    {:ok, base_url: base_url}
  end

  test "Ex4pm.Engine.Beam4pm (existing route-table client) is untouched by this additive path" do
    assert Ex4pm.Engine.Beam4pm.id() == :beam4pm
    assert Ex4pm.Engine.Beam4pm.supports?(:beam4pm_ocel_events, [])
    assert Ex4pm.Engine.Beam4pm.supports?(:beam4pm_conformance_results, [])
  end

  test "skills/0 exposes exactly the same 2 curated skills as beam4pm's ash_ai tools" do
    assert Beam4pmA2A.skills() == %{
             beam4pm_ocel_events: "read_ocel_events",
             beam4pm_conformance_results: "read_conformance_results"
           }
  end

  test "a real A2A.Client.discover/2 against a real mounted A2A agent returns a real AgentCard", %{
    base_url: base_url
  } do
    assert {:ok, card} = Beam4pmA2A.discover(base_url <> "/a2a")
    assert card.name == "beam4pm_a2a_agent"
    skill_ids = Enum.map(card.skills, & &1.id)
    assert "read_ocel_events" in skill_ids
    assert "read_conformance_results" in skill_ids
  end

  test "a real A2A.Client.send_message/3 round trip for read_ocel_events returns real dispatched data", %{
    base_url: base_url
  } do
    assert {:ok, %{task: task, data: data}} =
             Beam4pmA2A.call_skill(:beam4pm_ocel_events, beam4pm_a2a_base_url: base_url <> "/a2a")

    assert task.status.state == :completed
    assert %{"results" => [%{"id" => "evt-1", "activity" => "commit_qualified"}]} = data
  end

  test "a real A2A.Client.send_message/3 round trip for read_conformance_results returns real dispatched data", %{
    base_url: base_url
  } do
    assert {:ok, %{task: task, data: data}} =
             Beam4pmA2A.call_skill(:beam4pm_conformance_results, beam4pm_a2a_base_url: base_url <> "/a2a")

    assert task.status.state == :completed
    assert %{"results" => [%{"id" => "cr-1", "fitness" => 1.0}]} = data
  end

  test "an unadmitted operation is refused, never silently attempted" do
    assert {:error, refusal} = Beam4pmA2A.call_skill(:not_a_curated_skill, beam4pm_a2a_base_url: "http://127.0.0.1:1")
    assert refusal.code == :beam4pm_a2a_unsupported_operation
  end

  test "no configured base_url is refused as unavailable, not a crash" do
    assert {:error, refusal} = Beam4pmA2A.call_skill(:beam4pm_ocel_events, [])
    assert refusal.code == :beam4pm_a2a_unavailable
  end

  test "a real connection failure (server not listening) is refused as unavailable" do
    assert {:error, refusal} =
             Beam4pmA2A.call_skill(:beam4pm_ocel_events, beam4pm_a2a_base_url: "http://127.0.0.1:1/a2a")

    assert refusal.code == :beam4pm_a2a_unavailable
  end

  test "call_skill/2 also resolves base_url from Application.get_env when opts omit it", %{base_url: base_url} do
    Application.put_env(:ex4pm, :beam4pm_a2a_base_url, base_url <> "/a2a")
    on_exit(fn -> Application.delete_env(:ex4pm, :beam4pm_a2a_base_url) end)

    assert {:ok, %{data: data}} = Beam4pmA2A.call_skill(:beam4pm_ocel_events, [])
    assert %{"results" => [_ | _]} = data
  end
end
