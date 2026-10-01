defmodule Mix.Tasks.Ex4pm.Ferroplan.Readiness do
  @moduledoc """
  Executes the ferroplan wasm `readiness` op (capability manifest + fingerprint) and
  prints it.

      mix ex4pm.ferroplan.readiness

  Refusal (non-zero exit): `REFUSED_FERROPLAN_<CODE>`.
  """
  use Mix.Task

  @shortdoc "Runs the ferroplan wasm readiness op"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case Ex4pm.ferroplan(:readiness) do
      {:ok, run} ->
        Mix.shell().info(
          Jason.encode!(
            Ex4pm.CLI.to_json(%{
              standing: run.standing,
              readiness: run.value,
              receipt: run.receipt.hash
            }),
            pretty: true
          )
        )

      {:error, refusal} ->
        Mix.raise(Mix.Tasks.Ex4pm.Ferroplan.Verify.refused(refusal))
    end
  end
end
