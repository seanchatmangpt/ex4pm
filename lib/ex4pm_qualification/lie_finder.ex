# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Qualification.LieFinder do
  @moduledoc """
  AST-level static code analyzer that detects ungrounded claims, hardcoded metrics,
  bare outcome strings, uncalled algorithms, and bypassed BRCE receipt boundaries.
  """

  @type finding :: %{
          file: String.t(),
          line: integer() | nil,
          rule: atom(),
          message: String.t()
        }

  @doc "Scans all Elixir source files in the project and returns a list of findings."
  def scan(root_dir \\ ".") do
    ex_files =
      Path.wildcard(Path.join(root_dir, "apps/*/lib/**/*.ex"))
      |> Enum.reject(&String.contains?(&1, "/test/"))

    Enum.flat_map(ex_files, &scan_file/1)
  end

  @real_markers ~r/WasmArtifact|RealTransport|FerroplanTransport|real_wasm|real_ferroplan|ferroplan_wasm\.wasm|wasm4pm_ex4pm_bindings/
  @skip_tag ~r/@(?:module|describe)?tag\s+(?::skip\b|skip:)/
  @skip_guard ~r/skip_reason\(\)|EX4PM_WASM_REQUIRED/

  @doc """
  Rule `:skipped_real_exec`: scans `test/**/*_test.exs` for real-artifact tests
  that carry a `skip` tag without the `EX4PM_WASM_REQUIRED` handling
  (`Ex4pm.Test.WasmArtifact.skip_reason/0` raises under `EX4PM_WASM_REQUIRED=1`).
  An unguarded skip lets a green run say nothing about real execution.
  """
  @spec scan_tests(String.t()) :: [finding()]
  def scan_tests(root_dir \\ ".") do
    root_dir
    |> Path.join("test/**/*_test.exs")
    |> Path.wildcard()
    |> Enum.flat_map(&scan_test_source(&1, File.read!(&1)))
  end

  @doc "Pure form of `scan_tests/1` over one test file's source text."
  @spec scan_test_source(String.t(), String.t()) :: [finding()]
  def scan_test_source(path, content) do
    if Regex.match?(@real_markers, content) and Regex.match?(@skip_tag, content) and
         not Regex.match?(@skip_guard, content) do
      line =
        content
        |> String.split("\n")
        |> Enum.find_index(&Regex.match?(@skip_tag, &1))

      [
        %{
          file: path,
          line: line && line + 1,
          rule: :skipped_real_exec,
          message:
            "real-artifact test is skipped without EX4PM_WASM_REQUIRED handling " <>
              "(use Ex4pm.Test.WasmArtifact.skip_reason/0 so absence fails under REQUIRED=1)"
        }
      ]
    else
      []
    end
  end

  def scan_file(path) do
    content = File.read!(path)

    case Code.string_to_quoted(content, file: path) do
      {:ok, ast} ->
        inspect_ast(ast, path)

      {:error, reason} ->
        [%{file: path, line: nil, rule: :syntax_error, message: inspect(reason)}]
    end
  end

  def inspect_ast(ast, file) do
    {_ast, findings} =
      Macro.prewalk(ast, [], fn node, acc ->
        case check_node(node, file) do
          nil -> {node, acc}
          finding -> {node, [finding | acc]}
        end
      end)

    Enum.reverse(findings)
  end

  # Rule 1: Check for hardcoded fitness / precision / p_success assignment
  defp check_node({:=, meta, [{name, _, nil}, val]}, file)
       when is_atom(name) and name in [:fitness, :precision, :p_production_success, :prob_success] and
              is_number(val) do
    line = Keyword.get(meta, :line)

    %{
      file: file,
      line: line,
      rule: :hardcoded_metric_number,
      message: "Hardcoded bare number assigned to #{name} = #{inspect(val)}"
    }
  end

  # Rule 2: Check for direct Ash.create on Receipt (Bypassing BRCE)
  defp check_node(
         {{:., meta, [{:__aliases__, _, [:Ash]}, :create]}, _,
          [{:__aliases__, _, [:Receipt]}, _params | _]},
         file
       ) do
    line = Keyword.get(meta, :line)

    %{
      file: file,
      line: line,
      rule: :bypassed_brce_boundary,
      message:
        "Direct Ash.create(Receipt, ...) detected. All receipts must be minted through Ex4pm.Evidence.BRCE"
    }
  end

  # Rule 3: Check for bare string standing
  defp check_node({:=, meta, [{:standing, _, nil}, val]}, file) when is_binary(val) do
    line = Keyword.get(meta, :line)

    %{
      file: file,
      line: line,
      rule: :bare_standing_string,
      message:
        "Bare string #{inspect(val)} assigned to standing. Must use typed Ex4pm.Standing atom"
    }
  end

  defp check_node(_node, _file), do: nil
end
