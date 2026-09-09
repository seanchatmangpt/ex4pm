defmodule Mix.Tasks.Ex4pm.Engine.Gen.AdapterTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "generates a real, compilable adapter module containing the algorithm_id" do
    # Deliberately NOT "median" (or any real registered algorithm_id): this
    # test compiles the generated source with Code.compile_string/2, which
    # loads the module into the shared, global BEAM code server for the rest
    # of this (async) test run. Using a real production module name here
    # would clobber Ex4pmEngine.Wasm.Median with this test's minimal
    # generated stand-in, breaking every other test that calls the real
    # module's execute/3 -- a real, once-observed regression, not a
    # hypothetical.
    algorithm_id = "gen_adapter_test_fixture_algo"
    module_name = Module.concat(Ex4pmEngine.Wasm, Macro.camelize(algorithm_id))

    igniter =
      igniter_with_args(algorithm_id)
      |> Mix.Tasks.Ex4pm.Engine.Gen.Adapter.igniter()

    path = "lib/ex4pm_engine/wasm/#{algorithm_id}.ex"

    igniter =
      assert_creates(igniter, path, fn contents ->
        assert contents =~ "defmodule #{inspect(module_name)} do"
        assert contents =~ ":#{algorithm_id}"
        assert contents =~ "def algorithm_id, do: @algorithm_id"
        assert contents =~ "Ex4pm.Engine.Wasm.execute(@algorithm_id, subject, opts)"
      end)

    source = igniter.rewrite.sources[path]
    contents = Rewrite.Source.get(source, :content)

    {:ok, ast} = Code.string_to_quoted(contents, file: path)
    assert {:defmodule, _, _} = ast

    try do
      [{module, _bytecode}] = Code.compile_string(contents, path)
      assert module == module_name
      assert module.algorithm_id() == String.to_atom(algorithm_id)
      assert module.export() == algorithm_id
    after
      # Real cleanup: unload the dynamically-compiled fixture module so it
      # never lingers in the shared code server past this test.
      :code.delete(module_name)
      :code.purge(module_name)
    end
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
