defmodule Ex4pm.Application do
  @moduledoc """
  Top-level OTP application for the flat `ex4pm` library.

  Starts the evidence-store supervision tree (formerly
  `Ex4pm.Evidence.Application`) and the runtime supervisor (formerly
  `Ex4pm.Runtime.Application`) under one supervisor now that the umbrella's
  separate per-app `Application` callbacks have been merged into a single
  installed OTP application.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [{Ex4pm.Evidence.Store, name: Ex4pm.Evidence.Store}] ++
        wasm_host_children()

    Supervisor.start_link(children, strategy: :one_for_one, name: Ex4pm.Supervisor)
  end

  # `config :ex4pm, :wasm_host, true | false` (default true). A missing or
  # unadmitted artifact never fails boot: the Host starts and reports a typed
  # refusal instead.
  defp wasm_host_children do
    if Application.get_env(:ex4pm, :wasm_host, true) do
      [
        Ex4pmEngine.Wasm.Host,
        %{
          id: Ex4pm.Engine.Ferroplan.Host,
          start:
            {GenServer, :start_link,
             [Ex4pm.Engine.Ferroplan.Host, %{}, [name: Ex4pm.Engine.Ferroplan.Host]]},
          restart: :permanent
        }
      ]
    else
      []
    end
  end
end
