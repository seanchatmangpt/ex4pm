defmodule Ex4pmGgenVerifyDeterminismTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  @moduledoc """
  Chicago-style: runs the real `mix ex4pm.ggen.verify_determinism` task (via
  `Mix.Task.run/2` in-process) against the real `standing_coded` generation unit --
  real ontology file, real query file, real EEx template, real checked-in output
  file on disk. No mocks: the task shells out to the real `Ex4pm.Ggen.Generator`,
  writes to a real scratch file under `System.tmp_dir!/0`, and byte-diffs real file
  contents.
  """

  @unit %{
    ontology: "priv/ggen/units/standing_coded/ontology.ttl",
    queries: %{"standings" => "priv/ggen/units/standing_coded/standings.rq"},
    template: "priv/ggen/templates/standing_coded.ex.eex",
    out: "lib/ex4pm/standing/coded.ex"
  }

  test "Ex4pm.Standing.Coded's real generation unit reports deterministic via mix task" do
    for path <- [@unit.ontology, @unit.queries["standings"], @unit.template, @unit.out] do
      assert File.exists?(path), "expected real file #{path} to exist on disk"
    end

    Mix.Task.reenable("ex4pm.ggen.verify_determinism")

    output =
      capture_io(fn ->
        Mix.Task.run("ex4pm.ggen.verify_determinism", [
          "--ontology",
          @unit.ontology,
          "--query",
          "standings=#{@unit.queries["standings"]}",
          "--template",
          @unit.template,
          "--out",
          @unit.out
        ])
      end)

    assert output =~ "deterministic: #{@unit.out}"
  end

  test "Ex4pm.Ggen.Generator.render/2 regenerating the real unit is byte-identical to the checked-in file" do
    checked_in = File.read!(@unit.out)

    scratch =
      Path.join(
        System.tmp_dir!(),
        "ex4pm_ggen_generator_test_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm(scratch) end)

    assert {:ok, regenerated} = Ex4pm.Ggen.Generator.render(@unit, scratch)
    assert regenerated == checked_in

    assert Ex4pm.Standing.Coded.standings() == [
             :UNKNOWN,
             :PARTIAL_ALIVE,
             :ALIVE,
             :BLOCKED,
             :BUILD_BROKEN,
             :UNSUPPORTED,
             :REFUSED
           ]
  end
end
