defmodule Mix.Tasks.Ex4pm.Engine.Gen.AdapterTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "generates a real, compilable adapter module containing the algorithm_id" do
    igniter =
      igniter_with_args("median")
      |> Mix.Tasks.Ex4pm.Engine.Gen.Adapter.igniter()

    path = "lib/ex4pm_engine/wasm/median.ex"

    igniter =
      assert_creates(igniter, path, fn contents ->
        assert contents =~ "defmodule Ex4pmEngine.Wasm.Median do"
        assert contents =~ ":median"
        assert contents =~ "def algorithm_id, do: @algorithm_id"
        assert contents =~ "Ex4pm.Engine.Wasm.execute(@algorithm_id, subject, opts)"
      end)

    source = igniter.rewrite.sources[path]
    contents = Rewrite.Source.get(source, :content)

    {:ok, ast} = Code.string_to_quoted(contents, file: path)
    assert {:defmodule, _, _} = ast

    [{module, _bytecode}] = Code.compile_string(contents, path)
    assert module == Ex4pmEngine.Wasm.Median
    assert module.algorithm_id() == :median
    assert module.export() == "median"
  end

  defp igniter_with_args(algorithm_id, opts \\ []) do
    args = %Igniter.Mix.Task.Args{
      argv: [],
      argv_flags: [],
      positional: %{algorithm_id: algorithm_id},
      options: opts
    }

    project = test_project()
    %{project | args: args}
  end

  test "respects an explicit --export override" do
    igniter =
      igniter_with_args("p95", export: "percentile_95")
      |> Mix.Tasks.Ex4pm.Engine.Gen.Adapter.igniter()

    path = "lib/ex4pm_engine/wasm/p95.ex"

    assert_creates(igniter, path, fn contents ->
      assert contents =~ ~s(@export "percentile_95")
    end)
  end
end
