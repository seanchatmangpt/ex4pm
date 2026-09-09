# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Qualification.LieFinderTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Qualification.LieFinder

  describe "Anti-Cheat AST Lie Finder" do
    test "detects hardcoded bare fitness number in snippet" do
      code = """
      defmodule TestModule do
        def compute do
          fitness = 1.0
          {:ok, fitness}
        end
      end
      """

      {:ok, ast} = Code.string_to_quoted(code)
      findings = LieFinder.inspect_ast(ast, "test.ex")

      assert length(findings) == 1
      assert hd(findings).rule == :hardcoded_metric_number
    end

    test "detects direct Ash.create on Receipt (BRCE boundary bypass)" do
      code = """
      defmodule TestModule do
        def mint do
          Ash.create(Receipt, %{hash: "abc", standing: :alive})
        end
      end
      """

      {:ok, ast} = Code.string_to_quoted(code)
      findings = LieFinder.inspect_ast(ast, "test.ex")

      assert length(findings) == 1
      assert hd(findings).rule == :bypassed_brce_boundary
    end

    test "detects bare standing string" do
      code = """
      defmodule TestModule do
        def check do
          standing = "alive"
          standing
        end
      end
      """

      {:ok, ast} = Code.string_to_quoted(code)
      findings = LieFinder.inspect_ast(ast, "test.ex")

      assert length(findings) == 1
      assert hd(findings).rule == :bare_standing_string
    end

    test "accepts genuine algorithmic computation" do
      code = """
      defmodule TestModule do
        def align do
          res = Ex4pmEngine.Alignment.align(["a"], %{transitions: %{}, initial_marking: ["p0"], final_marking: ["p1"]})
          {:ok, res.fitness}
        end
      end
      """

      {:ok, ast} = Code.string_to_quoted(code)
      findings = LieFinder.inspect_ast(ast, "test.ex")

      assert findings == []
    end
  end
end
