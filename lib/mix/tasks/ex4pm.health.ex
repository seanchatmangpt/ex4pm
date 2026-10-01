defmodule Mix.Tasks.Ex4pm.Health do
  @moduledoc """
  Prints `Ex4pm.health/1` as JSON (wasm4pm and ferroplan: artifact present, admitted,
  sha256, pin, probe, standing).

      mix ex4pm.health

  Exits non-zero (via `Mix.raise/1`) when the overall standing is `blocked` or
  `build_broken`:

    * `REFUSED_BLOCKED` -- an artifact is absent or not admitted.
    * `REFUSED_BUILD_BROKEN` -- an artifact is admitted but its probe call failed.
  """
  use Mix.Task

  @shortdoc "Prints wasm4pm + ferroplan health; non-zero when blocked/build_broken"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    health = Ex4pm.health()
    Mix.shell().info(Jason.encode!(Ex4pm.CLI.to_json(health), pretty: true))

    case health.standing do
      :blocked -> Mix.raise("REFUSED_BLOCKED: ex4pm health standing is blocked")
      :build_broken -> Mix.raise("REFUSED_BUILD_BROKEN: ex4pm health standing is build_broken")
      _ -> :ok
    end
  end
end
