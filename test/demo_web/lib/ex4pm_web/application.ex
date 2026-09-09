defmodule Ex4pmWeb.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Configure subscriber callback to broadcast events via PubSub
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

    opts = [strategy: :one_for_one, name: Ex4pmWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    Ex4pmWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
