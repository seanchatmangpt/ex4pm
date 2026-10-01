defmodule Mix.Tasks.Ex4pm.Ferroplan.Plan do
  @moduledoc """
  Plans a PDDL problem with the admitted ferroplan wasm artifact.

      mix ex4pm.ferroplan.plan DOMAIN.pddl PROBLEM.pddl

  Prints standing, receipt hash and the solution map. Refusals (non-zero exit):
  `REFUSED_USAGE` (wrong arguments), `REFUSED_NO_INPUT` (unreadable file),
  `REFUSED_FERROPLAN_<CODE>` (engine refusal).
  """
  use Mix.Task

  @shortdoc "Plans a PDDL domain/problem with ferroplan wasm"

  @impl Mix.Task
  def run([domain_path, problem_path]) do
    Mix.Task.run("app.start")

    with {:ok, domain} <- read(domain_path),
         {:ok, problem} <- read(problem_path) do
      case Ex4pm.ferroplan(:plan, %{domain: domain, problem: problem}) do
        {:ok, run} ->
          Mix.shell().info(
            Jason.encode!(
              Ex4pm.CLI.to_json(%{
                standing: run.standing,
                receipt: run.receipt.hash,
                solution: run.value
              }),
              pretty: true
            )
          )

        {:error, refusal} ->
          Mix.raise(Mix.Tasks.Ex4pm.Ferroplan.Verify.refused(refusal))
      end
    end
  end

  def run(_), do: Mix.raise("REFUSED_USAGE: mix ex4pm.ferroplan.plan DOMAIN.pddl PROBLEM.pddl")

  defp read(path) do
    case File.read(path) do
      {:ok, text} -> {:ok, text}
      {:error, reason} -> Mix.raise("REFUSED_NO_INPUT: cannot read #{path} (#{reason})")
    end
  end
end
