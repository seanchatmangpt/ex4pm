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
    children = [
      {Ex4pm.Evidence.Store, name: Ex4pm.Evidence.Store}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Ex4pm.Supervisor)
  end
end
