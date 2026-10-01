defmodule Mix.Tasks.Ex4pm.Ferroplan.Version do
  @moduledoc """
  Executes the ferroplan wasm `version` op (a real wasm call, receipted) and prints it.

      mix ex4pm.ferroplan.version

  Refusal (non-zero exit): `REFUSED_FERROPLAN_<CODE>` where `<CODE>` is the upcased
  `Ex4pm.Refusal` code (e.g. `REFUSED_FERROPLAN_ARTIFACT_MISSING`).
  """
  use Mix.Task

  @shortdoc "Runs the ferroplan wasm version op"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case Ex4pm.ferroplan(:version) do
      {:ok, run} ->
        Mix.shell().info(
          Jason.encode!(
            Ex4pm.CLI.to_json(%{
              standing: run.standing,
              version: run.value,
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
