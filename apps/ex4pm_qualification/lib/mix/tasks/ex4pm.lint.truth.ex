# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Ex4pm.Lint.Truth do
  @moduledoc """
  Anti-Cheat Static Linter.
  Enforces zero-tolerance for hardcoded metrics, bare outcome strings,
  uncalled analytical algorithms, and bypassed BRCE boundaries.
  """
  use Mix.Task

  alias Ex4pm.Qualification.LieFinder

  @shortdoc "Scans codebase for ungrounded claims, hardcoded metrics, and pseudo-receipts"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    root = List.first(args) || "."
    findings = LieFinder.scan(root)

    if findings == [] do
      Mix.shell().info("\n=======================================================")
      Mix.shell().info("  ✓ LIE FINDER: 100% TRUTHFUL CODEBASE (0 LIES DETECTED)")
      Mix.shell().info("=======================================================\n")
    else
      Mix.shell().error("\n=======================================================")
      Mix.shell().error("  ❌ LIE FINDER DETECTED #{length(findings)} UNGROUNDED CLAIM(S):")
      Mix.shell().error("=======================================================")

      Enum.each(findings, fn f ->
        Mix.shell().error("  [#{f.rule}] #{f.file}:#{f.line || ~c"?"}")
        Mix.shell().error("    -> #{f.message}")
      end)

      Mix.shell().error("")
      Mix.raise("Codebase contains ungrounded claims or bypassed BRCE boundaries!")
    end
  end
end
