defmodule Mix.Tasks.Ex4pm.Ferroplan.Verify do
  @moduledoc """
  Verifies the ferroplan wasm artifact: present, digest admitted against
  `priv/ferroplan/MANIFEST.json`, and a real `version` + `readiness` execution.

      mix ex4pm.ferroplan.verify

  Refusals (non-zero exit):

    * `REFUSED_NO_ARTIFACT` -- artifact file absent.
    * `REFUSED_NOT_ADMITTED` -- digest missing/mismatched against the pin.
    * `REFUSED_FERROPLAN_<CODE>` -- the real wasm call was refused.
  """
  use Mix.Task

  alias Ex4pm.Engine.Ferroplan

  @shortdoc "Admits the ferroplan wasm artifact and executes version + readiness"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    path = Ferroplan.artifact_path()

    unless Ferroplan.wasm_built?(), do: Mix.raise("REFUSED_NO_ARTIFACT: #{path}")

    unless Ferroplan.available?([]),
      do: Mix.raise("REFUSED_NOT_ADMITTED: ferroplan digest not admitted for #{path}")

    for op <- [:version, :readiness] do
      case Ex4pm.ferroplan(op) do
        {:ok, run} -> Mix.shell().info("ferroplan #{op}: #{run.standing}")
        {:error, refusal} -> Mix.raise(refused(refusal))
      end
    end

    Mix.shell().info("mix ex4pm.ferroplan.verify: ok (#{path})")
    :ok
  end

  @doc false
  @spec refused(term()) :: String.t()
  def refused(%Ex4pm.Refusal{code: code, message: message}),
    do:
      "REFUSED_FERROPLAN_#{code |> Atom.to_string() |> String.replace_prefix("ferroplan_", "") |> String.upcase()}: #{message}"

  def refused(other), do: "REFUSED_FERROPLAN_ERROR: #{inspect(other)}"
end
