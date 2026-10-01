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

  defp scratch_dir! do
    # ggen_igniter's authorized root is the project, so scratch inputs live
    # under the already-gitignored .ggen_igniter_tmp/.
    d = Path.join(File.cwd!(), ".ggen_igniter_tmp/sync_task_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(d)
    on_exit(fn -> File.rm_rf!(d) end)
    d
  end

  test "an extra_ontologies path that does not exist aborts naming the unit and the missing input", %{dir: dir} do
    path =
      write_manifest!(dir, [
        %{
          "name" => "unit_with_missing_extra",
          "ontology" => "priv/ontology/ex4pm.ttl",
          "extra_ontologies" => [Path.join(dir, "no_such_extra.ttl")],
          "query_bindings" => %{},
          "template" => "priv/ggen/templates/standing_coded.ex.eex",
          "out" => Path.join(dir, "never_written.ex"),
          "test_path" => nil
        }
      ])

    {output, exit_code} = run_sync(["--manifest", path])

    assert exit_code != 0
    assert output =~ "FAILED at unit unit_with_missing_extra"
    assert output =~ "ontology input(s) not found"
    refute File.exists?(Path.join(dir, "never_written.ex"))
  end

  test "a vendored input whose sha256 differs from the lock refuses the unit" do
    d = scratch_dir!()
    vendor = Path.join(d, "vendor")
    File.mkdir_p!(vendor)
    File.write!(Path.join(vendor, "x.ontology.ttl"), "@prefix ex: <https://example.org/> .\nex:a ex:b ex:c .\n")

    File.write!(
      Path.join(vendor, "PACKS.lock.json"),
      Jason.encode!(%{
        "packs" => [%{"name" => "x", "files" => [%{"path" => "x.ontology.ttl", "sha256" => String.duplicate("0", 64)}]}]
      })
    )

    manifest =
      write_manifest!(d, [
        %{
          "name" => "locked_unit",
          "ontology" => "priv/ontology/ex4pm.ttl",
          "extra_ontologies" => [Path.join(vendor, "x.ontology.ttl")],
          "vendor_lock" => Path.join(vendor, "PACKS.lock.json"),
          "query_bindings" => %{},
          "template" => "priv/ggen/templates/standing_coded.ex.eex",
          "out" => Path.join(d, "never_written.ex"),
          "test_path" => nil
        }
      ])

    {output, exit_code} = run_sync(["--manifest", manifest])

    assert exit_code != 0
    assert output =~ "FAILED at unit locked_unit"
    assert output =~ "re-run priv/ggen/vendor/sync.sh"
    refute File.exists?(Path.join(d, "never_written.ex"))
  end

  test "a gate that returns any row refuses the unit before generation" do
    d = scratch_dir!()
    File.write!(Path.join(d, "o.ttl"), "@prefix ex: <https://example.org/> .\nex:a ex:b ex:c .\n")
    File.write!(Path.join(d, "always_fires.rq"), "SELECT ?s WHERE { ?s ?p ?o } LIMIT 1\n")

    manifest =
      write_manifest!(d, [
        %{
          "name" => "gated_unit",
          "ontology" => Path.join(d, "o.ttl"),
          "gates" => [Path.join(d, "always_fires.rq")],
          "query_bindings" => %{},
          "template" => "priv/ggen/templates/standing_coded.ex.eex",
          "out" => Path.join(d, "never_written.ex"),
          "test_path" => nil
        }
      ])

    {output, exit_code} = run_sync(["--manifest", manifest])

    assert exit_code != 0
    assert output =~ "FAILED at unit gated_unit"
    assert output =~ "gate(s) refused"
    assert output =~ "always_fires.rq: 1 row(s)"
    refute File.exists?(Path.join(d, "never_written.ex"))
  end
end
