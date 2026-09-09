defmodule Ex4pmGgenSyncTaskTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  # Real, no-mock test: shells out to the actual `mix ex4pm.ggen.sync` Mix
  # task as a subprocess, against real temporary manifest JSON files written
  # to a real scratch directory (System.tmp_dir!/0). Tagged :integration
  # (excluded from the fast default `mix test` per test/test_helper.exs,
  # included by `mix test.integration`/`mix verify`) since it shells out to
  # real `mix ggen_igniter.sync`/`mix compile`/`mix test` subprocess
  # invocations each run -- same pattern as
  # test/ex4pm_ggen_verify_determinism_test.exs.

  setup do
    dir = Path.join(System.tmp_dir!(), "ex4pm_ggen_sync_task_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  defp write_manifest!(dir, content) when is_binary(content) do
    path = Path.join(dir, "manifest.json")
    File.write!(path, content)
    path
  end

  defp write_manifest!(dir, units) when is_list(units) do
    write_manifest!(dir, Jason.encode!(units))
  end

  defp run_sync(args) do
    System.cmd("mix", ["ex4pm.ggen.sync" | args], stderr_to_stdout: true)
  end

  test "missing manifest file produces a clear error and non-zero exit", %{dir: dir} do
    missing_path = Path.join(dir, "does_not_exist.json")

    {output, exit_code} = run_sync(["--manifest", missing_path])

    assert exit_code != 0
    assert output =~ "manifest not found at #{missing_path}"
  end

  test "manifest with invalid JSON syntax produces a clear error and non-zero exit", %{dir: dir} do
    path = write_manifest!(dir, "{not valid json[")

    {output, exit_code} = run_sync(["--manifest", path])

    assert exit_code != 0
    assert output =~ "is not valid JSON"
  end

  test "manifest that is valid JSON but not a JSON array produces a clear error and non-zero exit", %{dir: dir} do
    path = write_manifest!(dir, ~s({"name": "not_an_array"}))

    {output, exit_code} = run_sync(["--manifest", path])

    assert exit_code != 0
    assert output =~ "must be a JSON array"
  end

  test "--unit filter naming a unit not in the manifest produces a clear error and non-zero exit", %{dir: dir} do
    path =
      write_manifest!(dir, [
        %{
          "name" => "real_unit",
          "ontology" => "priv/ontology/ex4pm.ttl",
          "query_bindings" => %{},
          "template" => "some_template.eex",
          "out" => "some_out.ex",
          "test_path" => nil
        }
      ])

    {output, exit_code} = run_sync(["--manifest", path, "--unit", "nonexistent_unit"])

    assert exit_code != 0
    assert output =~ "no unit named \"nonexistent_unit\" in the manifest"
  end

  test "empty manifest array produces the documented info message and exits 0", %{dir: dir} do
    path = write_manifest!(dir, [])

    {output, exit_code} = run_sync(["--manifest", path])

    assert exit_code == 0
    assert output =~ "no generation units to run"
  end

  test "a unit whose ontology/template/out files don't exist aborts the whole run naming that exact unit", %{
    dir: dir
  } do
    path =
      write_manifest!(dir, [
        %{
          "name" => "broken_unit_that_does_not_exist_anywhere",
          "ontology" => Path.join(dir, "nonexistent_ontology.ttl"),
          "query_bindings" => %{"admitted" => Path.join(dir, "nonexistent_query.rq")},
          "template" => Path.join(dir, "nonexistent_template.eex"),
          "out" => Path.join(dir, "generated_out.ex"),
          "test_path" => nil
        }
      ])

    {output, exit_code} = run_sync(["--manifest", path])

    assert exit_code != 0

    assert output =~
             "FAILED at unit broken_unit_that_does_not_exist_anywhere"

    assert output =~ "Aborting -- no further units were synced"

    # Real behavior, not assumed: the out file must not have been written by
    # a partially-successful sync.
    refute File.exists?(Path.join(dir, "generated_out.ex"))
  end
end
