# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Qualification.Scanners.ProductionPurger do
  @moduledoc """
  Tier 2 Static Scanner: Detects mocks, stubs, fakes, or ungrounded mock adapters
  in non-test production code.
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

  defp check_node({:defmodule, meta, [{:__aliases__, _, aliases}, _]}, file) do
    mod_name = Enum.map_join(aliases, ".", &to_string/1)

    if not String.contains?(file, "mock_purger.ex") and
         (String.contains?(mod_name, "Mock") or String.contains?(mod_name, "Fake") or
            String.contains?(mod_name, "Stub")) do
      %{
        scanner: :mock_purger,
        file: file,
        line: Keyword.get(meta, :line),
        severity: :error,
        message: "Prohibited Mock/Fake/Stub module definition in production library: #{mod_name}"
      }
    else
      nil
    end
  end

  defp check_node(_node, _file), do: nil
end
