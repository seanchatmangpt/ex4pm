defmodule Ex4pm.Evidence.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([{Ex4pm.Evidence.Store, name: Ex4pm.Evidence.Store}],
      strategy: :one_for_one,
      name: Ex4pm.Evidence.Supervisor
    )
  end
end
