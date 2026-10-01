defmodule Mix.Tasks.Ex4pm.Wasm.Doctor do
  @moduledoc """
  Diagnoses the wasm4pm artifact: health (`Ex4pm.health/1`, wasm4pm section) plus the
  standing of each of the 33 algorithm engines (`Ex4pm.wasm/1`).

      mix ex4pm.wasm.doctor

  Refusals (non-zero exit): `REFUSED_BLOCKED` (artifact absent or not admitted),
  `REFUSED_BUILD_BROKEN` (admitted, probe failed).
  """
  use Mix.Task

  @shortdoc "Diagnoses the wasm4pm artifact and its 33 algorithm engines"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    health = Ex4pm.health().wasm4pm
    engines = Ex4pm.wasm()

    Mix.shell().info(
      Jason.encode!(Ex4pm.CLI.to_json(%{wasm4pm: health, engines: engines}), pretty: true)
    )

    case health.standing do
      :blocked -> Mix.raise("REFUSED_BLOCKED: wasm4pm artifact absent or not admitted")
      :build_broken -> Mix.raise("REFUSED_BUILD_BROKEN: wasm4pm admitted but probe failed")
      _ -> :ok
    end
  end
end
