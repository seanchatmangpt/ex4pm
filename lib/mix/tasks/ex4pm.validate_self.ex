defmodule Mix.Tasks.Ex4pm.ValidateSelf do
  @moduledoc """
  Autonomous Self-Conformance Validation Mix Task.

  Executes `Ex4pmEngine.Reactors.SelfConformanceReactor` against real production
  IEEE OCEL 2.0 NDJSON logs and outputs the complete process discovery and 5D conformance calculus.

  Usage:
      mix ex4pm.validate_self --path /Users/sac/xaas/priv/ocel/ash-actions.ndjson --limit 10000
  """

  use Mix.Task

  alias Ex4pmEngine.Reactors.SelfConformanceReactor

  @shortdoc "Validates ex4pm self-conformance against real OCEL production logs via Reactor"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [path: :string, limit: :integer],
        aliases: [p: :path, l: :limit]
      )

    path = Keyword.get(opts, :path, "/Users/sac/xaas/priv/ocel/ash-actions.ndjson")
    limit = Keyword.get(opts, :limit, 10_000)

    Mix.shell().info("\n=======================================================")
    Mix.shell().info("  Ex4pm Autonomous Self-Conformance Reactor Execution")
    Mix.shell().info("=======================================================")
    Mix.shell().info("Target OCEL Path: #{path}")
    Mix.shell().info("Event Limit:      #{limit}\n")

    t_start = System.monotonic_time(:millisecond)

    case Reactor.run(SelfConformanceReactor, %{ocel_path: path, limit: limit, target_ir: nil}) do
      {:ok, report} ->
        elapsed_ms = System.monotonic_time(:millisecond) - t_start
        throughput = Float.round(report.total_events / max(1, elapsed_ms / 1000), 2)

        Mix.shell().info("=== PROCESS DISCOVERY RESULTS ===")
        Mix.shell().info("Total Events Ingested:   #{report.total_events}")
        Mix.shell().info("Discovered Activities:   #{report.discovered_activities}")
        Mix.shell().info("Discovered Transitions:  #{report.discovered_transitions}")
        Mix.shell().info("Unique Process Variants: #{report.unique_variants}")
        Mix.shell().info("Elapsed Time:            #{elapsed_ms} ms (#{throughput} events/sec)\n")

        Mix.shell().info("=== 5-DIMENSIONAL CONFORMANCE VECTOR ===")
        Mix.shell().info("Fitness:                 #{Float.round(report.conformance.fitness, 4)}")

        Mix.shell().info(
          "Precision:               #{Float.round(report.conformance.precision, 4)}"
        )

        Mix.shell().info(
          "Policy Conformance:      #{Float.round(report.conformance.policy_conformance, 4)}"
        )

        Mix.shell().info(
          "Lifecycle Conformance:   #{Float.round(report.conformance.lifecycle_conformance, 4)}"
        )

        Mix.shell().info(
          "Causal Conformance:      #{Float.round(report.conformance.causal_conformance, 4)}\n"
        )

        Mix.shell().info("=== W3C EARL 1.0 EVIDENCE PROOF ===")
        Mix.shell().info(report.earl_turtle)

        Mix.shell().info("=== FORMAL STANDING ===")
        Mix.shell().info("STANDING: #{report.standing} (Receipt ID: #{report.receipt.id})\n")

      {:error, reason} ->
        Mix.shell().error("Self-conformance validation failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
