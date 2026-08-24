# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Qualification.Scanners.BrceEnforcer do
  @moduledoc """
  Tier 4 Static Scanner: Enforces that state-changing domain operations and receipts
  are never created directly bypassing Ex4pm.Evidence.BRCE.
  """

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

  defp check_node(
         {{:., meta, [{:__aliases__, _, [:Ash]}, :create]}, _,
          [{:__aliases__, _, [:Receipt]}, _params | _]},
         file
       ) do
    %{
      scanner: :brce_enforcer,
      file: file,
      line: Keyword.get(meta, :line),
      severity: :error,
      message: "Direct Ash.create(Receipt) bypasses Ex4pm.Evidence.BRCE boundary law"
    }
  end

  defp check_node(_node, _file), do: nil
end
