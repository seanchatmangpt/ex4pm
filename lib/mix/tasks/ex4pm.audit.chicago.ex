# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Ex4pm.Audit.Chicago do
  @shortdoc "Audits 100% Chicago-style integration testing utilization"
  @moduledoc """
  Calculates and proves stateful Chicago test utilization across all 30 Ash resources,
  28 Reactors, and process mining algorithms.
  """
  use Mix.Task

  alias Ex4pm.Qualification.ChicagoAuditor

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("\n========================================================")
    Mix.shell().info("  EX4PM CHICAGO TEST SUITE UTILIZATION AUDITOR")
    Mix.shell().info("========================================================")

    audit = ChicagoAuditor.audit()

    Mix.shell().info("  Total Ash Resources:        #{audit.total_resources}")

    Mix.shell().info(
      "  Ash Resources Tested:       #{audit.resources_tested} (#{audit.resource_utilization}%)"
    )

    Mix.shell().info("  Total Reactor Sagas:        #{audit.total_reactors}")

    Mix.shell().info(
      "  Reactor Sagas Tested:       #{audit.reactors_tested} (#{audit.reactor_utilization}%)"
    )

    Mix.shell().info(
      "  Mining Algorithms Tested:   #{audit.algos_tested}/#{audit.total_algorithms} (#{audit.algo_utilization}%)"
    )

    Mix.shell().info("  Stateful Integration Tests: #{audit.chicago_tests_count}")
    Mix.shell().info("  Overall Chicago Coverage:   #{audit.overall_utilization}% UTILIZATION")
    Mix.shell().info("========================================================\n")

    if audit.overall_utilization >= 100.0 do
      Mix.shell().info("✓ CHICAGO QUALITY ASSURANCE: 100% UTILIZATION PROVEN\n")
    else
      Mix.shell().info(
        "⚠ CHICAGO QUALITY ASSURANCE: #{audit.overall_utilization}% UTILIZATION (not yet 100%)\n"
      )
    end

    :ok
  end
end
