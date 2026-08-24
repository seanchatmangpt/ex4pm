# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Qualification.Scanners.MetricLinter do
  @moduledoc """
  Tier 1 Static Scanner: Detects hardcoded floating-point numbers or raw percentages
  assigned to critical process intelligence metrics without evaluating underlying algorithms.
  """

  @suspicious_vars [:fitness, :precision, :p_production_success, :prob_success]

  def scan(root_dir \\ ".") do
    Path.wildcard(Path.join(root_dir, "apps/*/lib/**/*.ex"))
    |> Enum.flat_map(&scan_file/1)
  end

  def scan_file(path) do
    content = File.read!(path)

    case Code.string_to_quoted(content, file: path) do
      {:ok, ast} ->
        {_ast, findings} =
          Macro.prewalk(ast, [], fn node, acc ->
            case check_node(node, path) do
              nil -> {node, acc}
              f -> {node, [f | acc]}
            end
          end)

        findings

      _ ->
        []
    end
  end

  defp check_node({:=, meta, [{name, _, nil}, val]}, file)
       when is_atom(name) and name in @suspicious_vars and is_number(val) do
    if String.contains?(file, "default") or String.contains?(file, "test") do
      nil
    else
      %{
        scanner: :metric_linter,
        file: file,
        line: Keyword.get(meta, :line),
        severity: :error,
        message: "Hardcoded bare number assigned to metric variable #{name} = #{inspect(val)}"
      }
    end
  end

  defp check_node(_node, _file), do: nil
end
