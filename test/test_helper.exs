ExUnit.start(exclude: [:chicago, :integration, :stress])

# test/demo_web (Phoenix/LiveView demo harness) isn't part of the shipped
# :ex4pm application (it moved out of lib/ on purpose — see docs/ARCHITECTURE.md)
# so its supervision tree (formerly the standalone Ex4pmWeb.Application) has
# to be started here, test-only, for the demo controller/LiveView tests.
if Code.ensure_loaded?(Ex4pmWeb.Endpoint) do
  broadcast_fn = fn event_type, data ->
    Phoenix.PubSub.broadcast(
      Ex4pmWeb.PubSub,
      "process_intelligence:live",
      {:miner_update, event_type, data}
    )
  end

  children = [
    Ex4pmWeb.Telemetry,
    {Phoenix.PubSub, name: Ex4pmWeb.PubSub},
    {Ex4pm.Engine.OnlineMiner, [name: Ex4pm.Engine.OnlineMiner, subscriber: broadcast_fn]},
    {Ex4pmEngine.Autonomic.ClosedLoop, [interval_ms: 3000]},
    Ex4pmWeb.Endpoint
  ]

  {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one, name: Ex4pmWeb.Supervisor)
end
