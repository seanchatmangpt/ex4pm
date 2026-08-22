defmodule Ex4pmWeb.HealthController do
  use Ex4pmWeb, :controller

  def health(conn, _params) do
    json(conn, %{
      status: "ok",
      service: "ex4pm-process-intelligence-control-plane",
      standing: :alive,
      beam_nodes: Node.list()
    })
  end

  def ready(conn, _params) do
    miner_alive = is_pid(Process.whereis(Ex4pm.Engine.OnlineMiner))
    store_alive = is_pid(Process.whereis(Ex4pm.Evidence.Store))

    if miner_alive and store_alive do
      json(conn, %{ready: true, miner: :alive, store: :alive})
    else
      conn
      |> put_status(503)
      |> json(%{ready: false, miner: miner_alive, store: store_alive})
    end
  end
end
