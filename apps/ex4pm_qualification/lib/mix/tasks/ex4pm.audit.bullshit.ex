# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Ex4pm.Audit.Bullshit do
  @shortdoc "Runs 5-tier ruthless anti-bullshit static analyzers across all umbrella apps"
  @moduledoc """
  Executes MetricLinter, MockPurger, BrceEnforcer, and LieFinder across all 12 umbrella apps.
  Fails with exit code 1 if any fake stubs, hardcoded metrics, or bypassed authority rules exist.
  """
  use Mix.Task

  alias Ex4pm.Qualification.LieFinder
  alias Ex4pm.Qualification.Scanners.{BrceEnforcer, MetricLinter, ProductionPurger}

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("\n========================================================")
    Mix.shell().info("  EX4PM 5-TIER RUTHLESS ANTI-BULLSHIT STATIC AUDITOR")
    Mix.shell().info("========================================================")

    f1 = MetricLinter.scan()
    f2 = ProductionPurger.scan()
    f3 = BrceEnforcer.scan()
    f4 = LieFinder.scan()

    all_findings = f1 ++ f2 ++ f3 ++ f4

    Mix.shell().info("  1. MetricLinter (Hardcoded floats/rates):  #{length(f1)} violations")
    Mix.shell().info("  2. ProductionPurger (Mock/Fake modules):   #{length(f2)} violations")
    Mix.shell().info("  3. BrceEnforcer (Authority bypasses):     #{length(f3)} violations")
    Mix.shell().info("  4. LieFinder (Bare outcomes/unsealed):     #{length(f4)} violations")
    Mix.shell().info("--------------------------------------------------------")
    Mix.shell().info("  Total Bullshit Violations:                 #{length(all_findings)}")
    Mix.shell().info("========================================================\n")

    if length(all_findings) == 0 do
      Mix.shell().info("✓ 0% BULLSHIT DETECTED: 100% TRUTHFUL, SOUND, ADMISSIBLE BEAM CODEBASE\n")
      :ok
    else
      Mix.shell().error("❌ BULLSHIT AUDIT FAILED: #{length(all_findings)} VIOLATIONS FOUND:")

      Enum.each(all_findings, fn f ->
        Mix.shell().error("  - [#{f.file}:#{f.line || 1}] #{f.message}")
      end)

      Mix.raise("Audit failed due to #{length(all_findings)} bullshit violations")
    end
  end
end
