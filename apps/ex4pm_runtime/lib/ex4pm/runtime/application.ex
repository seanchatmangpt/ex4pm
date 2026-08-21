defmodule Ex4pm.Runtime.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([{Task.Supervisor, name: Ex4pm.Runtime.TaskSupervisor}],
      strategy: :one_for_one,
      name: Ex4pm.Runtime.Supervisor
    )
  end
end
