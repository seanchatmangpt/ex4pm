defmodule Ex4pmGgenVerifyDeterminismTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  # Real, no-mock test: shells out to the actual `mix ex4pm.ggen.sync`/
  # `mix ex4pm.ggen.verify_determinism` machinery, against this repo's real
  # ontology/query/template/out artifacts. Tagged :integration (excluded
  # from the fast default `mix test` per test/test_helper.exs, included by
  # `mix test.integration`/`mix verify`) since it shells out to a real
  # ggen_igniter sync invocation each run.

  test "standing_coded is a real, deterministic pure function of its ontology/query/template" do
    {output, exit_code} =
      System.cmd(
        "mix",
        [
          "ex4pm.ggen.verify_determinism",
          "--ontology",
          "priv/ontology/ex4pm.ttl",
          "--query",
          "admitted=priv/ggen/queries/admitted_standing_codes.rq",
          "--template",
          "priv/ggen/templates/standing_coded.ex.eex",
          "--out",
          "lib/ex4pm/standing_coded.ex"
        ],
        stderr_to_stdout: true
      )

    assert exit_code == 0, "expected mix ex4pm.ggen.verify_determinism to succeed, got:\n#{output}"
    assert output =~ "deterministic: lib/ex4pm/standing_coded.ex"
  end

  test "--all verifies every manifest unit and reports a real summary" do
    {output, exit_code} =
      System.cmd("mix", ["ex4pm.ggen.verify_determinism", "--all"], stderr_to_stdout: true)

    assert exit_code == 0, "expected --all to succeed against the real manifest, got:\n#{output}"
    assert output =~ "deterministic  standing_coded"
    assert output =~ "deterministic  standing_coded_test"
  end

  test "a tampered checked-in file is caught, named, and reported non-zero -- not fail-open" do
    original = File.read!("lib/ex4pm/standing_coded.ex")

    on_exit(fn -> File.write!("lib/ex4pm/standing_coded.ex", original) end)

    File.write!("lib/ex4pm/standing_coded.ex", original <> "\n# tampered by test\n")

    {output, exit_code} =
      System.cmd(
        "mix",
        [
          "ex4pm.ggen.verify_determinism",
          "--ontology",
          "priv/ontology/ex4pm.ttl",
          "--query",
          "admitted=priv/ggen/queries/admitted_standing_codes.rq",
          "--template",
          "priv/ggen/templates/standing_coded.ex.eex",
          "--out",
          "lib/ex4pm/standing_coded.ex"
        ],
        stderr_to_stdout: true
      )

    assert exit_code != 0
    assert output =~ "is NOT deterministic"
  end

  test "single-unit verify against a nonexistent checked-in output names the file and points at mix ex4pm.ggen.sync" do
    missing_out = "/tmp/ex4pm_verify_determinism_missing_#{:erlang.unique_integer([:positive])}.ex"
    refute File.exists?(missing_out)

    {output, exit_code} =
      System.cmd(
        "mix",
        [
          "ex4pm.ggen.verify_determinism",
          "--ontology",
          "priv/ontology/ex4pm.ttl",
          "--query",
          "admitted=priv/ggen/queries/admitted_standing_codes.rq",
          "--template",
          "priv/ggen/templates/standing_coded.ex.eex",
          "--out",
          missing_out
        ],
        stderr_to_stdout: true
      )

    assert exit_code != 0
    assert output =~ "checked-in output #{missing_out} does not exist -- run mix ex4pm.ggen.sync first"
  end

  test "single-unit invocation missing a required flag raises a clear usage error, not a crash" do
    {output, exit_code} =
      System.cmd(
        "mix",
        [
          "ex4pm.ggen.verify_determinism",
          "--ontology",
          "priv/ontology/ex4pm.ttl",
          "--template",
          "priv/ggen/templates/standing_coded.ex.eex"
        ],
        stderr_to_stdout: true
      )

    assert exit_code != 0

    assert output =~
             "pass --ontology/--query/--template/--out for one unit, or --all for every manifest unit."
  end

  test "--all against a missing manifest path is a documented no-op, not a failure" do
    missing_manifest = "/tmp/ex4pm_verify_determinism_no_manifest_#{:erlang.unique_integer([:positive])}.json"
    refute File.exists?(missing_manifest)

    {output, exit_code} =
      System.cmd("mix", ["ex4pm.ggen.verify_determinism", "--all", "--manifest", missing_manifest],
        stderr_to_stdout: true
      )

    assert exit_code == 0
    assert output =~ "no manifest at #{missing_manifest}, nothing to verify (not a failure)."
  end

  test "--all with multiple divergent units names every failing unit, not just the first" do
    standing_coded_original = File.read!("lib/ex4pm/standing_coded.ex")
    standing_coded_test_original = File.read!("test/standing_coded_test.exs")

    on_exit(fn ->
      File.write!("lib/ex4pm/standing_coded.ex", standing_coded_original)
      File.write!("test/standing_coded_test.exs", standing_coded_test_original)
    end)

    File.write!("lib/ex4pm/standing_coded.ex", standing_coded_original <> "\n# tampered A by test\n")
    File.write!("test/standing_coded_test.exs", standing_coded_test_original <> "\n# tampered B by test\n")

    manifest_path =
      Path.join(File.cwd!(), ".ggen_igniter_tmp/two_unit_manifest_#{:erlang.unique_integer([:positive])}.json")

    File.mkdir_p!(Path.dirname(manifest_path))

    manifest = [
      %{
        "name" => "standing_coded",
        "ontology" => "priv/ontology/ex4pm.ttl",
        "query_bindings" => %{"admitted" => "priv/ggen/queries/admitted_standing_codes.rq"},
        "template" => "priv/ggen/templates/standing_coded.ex.eex",
        "out" => "lib/ex4pm/standing_coded.ex",
        "test_path" => nil
      },
      %{
        "name" => "standing_coded_test",
        "ontology" => "priv/ontology/ex4pm.ttl",
        "query_bindings" => %{"admitted" => "priv/ggen/queries/admitted_standing_codes.rq"},
        "template" => "priv/ggen/templates/standing_coded_test.exs.eex",
        "out" => "test/standing_coded_test.exs",
        "test_path" => "test/standing_coded_test.exs"
      }
    ]

    File.write!(manifest_path, Jason.encode!(manifest))
    on_exit(fn -> File.rm(manifest_path) end)

    {output, exit_code} =
      System.cmd("mix", ["ex4pm.ggen.verify_determinism", "--all", "--manifest", manifest_path],
        stderr_to_stdout: true
      )

    assert exit_code != 0
    assert output =~ "DIVERGENT      standing_coded"
    assert output =~ "DIVERGENT      standing_coded_test"
    assert output =~ "2 unit(s) diverged."
    assert output =~ "unit standing_coded: lib/ex4pm/standing_coded.ex is NOT deterministic"
    assert output =~ "unit standing_coded_test: test/standing_coded_test.exs is NOT deterministic"
  end

  test "a unit whose regeneration command itself fails is labeled a regeneration failure, not confused with a determinism mismatch" do
    {output, exit_code} =
      System.cmd(
        "mix",
        [
          "ex4pm.ggen.verify_determinism",
          "--ontology",
          "/tmp/ex4pm_verify_determinism_no_such_ontology_#{:erlang.unique_integer([:positive])}.ttl",
          "--query",
          "admitted=priv/ggen/queries/admitted_standing_codes.rq",
          "--template",
          "priv/ggen/templates/standing_coded.ex.eex",
          "--out",
          "lib/ex4pm/standing_coded.ex"
        ],
        stderr_to_stdout: true
      )

    assert exit_code != 0
    assert output =~ "regeneration failed (exit"
    refute output =~ "is NOT deterministic"
  end
end
