defmodule Ex4pm.Engine.Ferroplan.SessionSupervisor do
  @moduledoc """
  Supervision pair for ferroplan sessions: a `Registry` (`SessionRegistry`,
  unique keys = session ids) and a `DynamicSupervisor`
  (`SessionSupervisor.Dynamic`) owning one `Ex4pm.Engine.Ferroplan.Session`
  per session (`restart: :temporary`).

  Started either from the application supervisor
  (`children: [..., Ex4pm.Engine.Ferroplan.SessionSupervisor]`) or lazily and
  idempotently by `Ex4pm.Engine.Ferroplan.Sessions.ensure_started/0`.
  `rest_for_one`: if the registry dies the dynamic supervisor (and with it
  every session, whose registered names would be stale) is restarted too.
  """
  use Supervisor

  @registry Ex4pm.Engine.Ferroplan.SessionRegistry
  @dynamic Ex4pm.Engine.Ferroplan.SessionSupervisor.Dynamic

  @doc false
  def registry, do: @registry
  @doc false
  def dynamic, do: @dynamic

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {DynamicSupervisor, strategy: :one_for_one, name: @dynamic}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
