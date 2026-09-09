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
end
