defmodule Mix.Tasks.Ex4pm.Ggen.Sync do
  @moduledoc """
  Runs the ggen_igniter ontology -> code generation pipeline for one or more
  generation units declared in a JSON manifest, then compiles and tests the
  result.

  Usage:

      mix ex4pm.ggen.sync
      mix ex4pm.ggen.sync --manifest priv/ggen/manifest.json

  Manifest shape (JSON array of units):

      [
        {
          "name": "ex4pm.standing_coded",
          "ontology": "priv/ontology/ex4pm.ttl",
          "query_bindings": {"select_coded_standing": "priv/ggen/queries/select_coded_standing.rq"},
          "template": "priv/ggen/templates/standing_coded.ex.eex",
          "out": "lib/ex4pm/standing_coded.ex",
          "test_path": "test/ex4pm/standing_coded_test.exs"
        }
      ]

  For each unit, in manifest order, this task shells out to
  `mix ggen_igniter.sync --ontology <ontology> --query <name>=<path> --template
  <template> --out <out>` (one `--query` flag per query binding). A unit
  failure aborts the whole run immediately and names the failing unit -- it
  never leaves a partial run silently reported as success.

  After every unit succeeds, this task runs `mix compile --warnings-as-errors`
  once, then `mix test` scoped to the union of each unit's `test_path` (units
  without a `test_path` are skipped for the test step, not for generation).
  """

  use Mix.Task

  @shortdoc "Syncs generated code from the ggen_igniter ontology pipeline per a manifest"

  @default_manifest "priv/ggen/manifest.json"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args, strict: [manifest: :string])

    manifest_path = Keyword.get(opts, :manifest, @default_manifest)

    units = load_manifest!(manifest_path)

    Mix.shell().info("ex4pm.ggen.sync: #{length(units)} unit(s) from #{manifest_path}")

    Enum.each(units, &sync_unit!/1)

    Mix.shell().info("ex4pm.ggen.sync: all units synced, compiling...")
    run_or_abort!("mix", ["compile", "--warnings-as-errors"], "compile --warnings-as-errors")

    test_paths =
      units
      |> Enum.map(&Map.get(&1, "test_path"))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if test_paths != [] do
      Mix.shell().info("ex4pm.ggen.sync: running tests for #{Enum.join(test_paths, ", ")}")
      run_or_abort!("mix", ["test" | test_paths], "test #{Enum.join(test_paths, " ")}")
    else
      Mix.shell().info("ex4pm.ggen.sync: no unit declared a test_path, skipping test step")
    end

    Mix.shell().info("ex4pm.ggen.sync: done")
  end

  defp load_manifest!(path) do
    unless File.exists?(path) do
      Mix.raise("ex4pm.ggen.sync: manifest not found at #{path}")
    end

    case Jason.decode(File.read!(path)) do
      {:ok, units} when is_list(units) ->
        units

      {:ok, _other} ->
        Mix.raise("ex4pm.ggen.sync: manifest #{path} must be a JSON array of units")

      {:error, error} ->
        Mix.raise("ex4pm.ggen.sync: manifest #{path} is not valid JSON: #{inspect(error)}")
    end
  end

  defp sync_unit!(%{"name" => name} = unit) do
    Mix.shell().info("ex4pm.ggen.sync: syncing unit #{name}")

    ontology = required!(unit, name, "ontology")
    template = required!(unit, name, "template")
    out = required!(unit, name, "out")
    query_bindings = Map.get(unit, "query_bindings", %{})

    query_flags =
      Enum.flat_map(query_bindings, fn {query_name, query_path} ->
        ["--query", "#{query_name}=#{query_path}"]
      end)

    args =
      ["ggen_igniter.sync", "--ontology", ontology, "--template", template, "--out", out] ++
        query_flags

    run_or_abort!("mix", args, "unit #{name}")
  end

  defp sync_unit!(unit) do
    Mix.raise("ex4pm.ggen.sync: manifest unit missing required \"name\" field: #{inspect(unit)}")
  end

  defp required!(unit, name, key) do
    case Map.get(unit, key) do
      nil -> Mix.raise("ex4pm.ggen.sync: unit #{name} is missing required field #{inspect(key)}")
      value -> value
    end
  end

  defp run_or_abort!(cmd, args, label) do
    case System.cmd(cmd, args, stderr_to_stdout: true, into: IO.stream(:stdio, :line)) do
      {_output, 0} ->
        :ok

      {_output, status} ->
        Mix.raise(
          "ex4pm.ggen.sync: FAILED at #{label} (#{cmd} #{Enum.join(args, " ")}), exit status #{status}. Aborting -- no further units were synced."
        )
    end
  end
end
