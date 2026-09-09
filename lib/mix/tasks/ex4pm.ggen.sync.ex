defmodule Mix.Tasks.Ex4pm.Ggen.Sync do
  @moduledoc """
  Runs every ggen_igniter generation unit declared in a manifest, then
  verifies the result -- replacing the bespoke per-consumer bash scripts
  (`scripts/standing_coded_sync.sh`) with one shared, general Mix task.

  Real, confirmed motivation (ERRC cluster c8, 2026-09-09 deep-search
  workflow): `scripts/standing_coded_sync.sh` hand-rolls "mix deps.get; N x
  mix ggen_igniter.sync calls; mix compile --warnings-as-errors; mix test"
  for exactly one consumer (`Ex4pm.Standing.Coded`); beam4pm's
  `scripts/gate_m2_check.sh` independently hand-rolls a much larger,
  documented-buggy version of the same idea. Neither has a real, general,
  in-BEAM Mix task. This is that task.

  ## Usage

      mix ex4pm.ggen.sync
      mix ex4pm.ggen.sync --manifest priv/ggen/manifest.json
      mix ex4pm.ggen.sync --unit standing_coded

  ## Manifest shape

  A JSON array of generation units:

      [
        {
          "name": "standing_coded",
          "ontology": "priv/ontology/ex4pm.ttl",
          "query_bindings": {"admitted": "priv/ggen/queries/admitted_standing_codes.rq"},
          "template": "priv/ggen/templates/standing_coded.ex.eex",
          "out": "lib/ex4pm/standing_coded.ex",
          "test_path": null
        }
      ]

  Each unit is passed to `mix ggen_igniter.sync` as:

      mix ggen_igniter.sync --ontology <ontology> \\
        --query <k>=<v> [--query <k>=<v> ...] \\
        --template <template> --out <out>

  ## Failure semantics

  A failed unit aborts the whole run immediately via `Mix.raise/1`, naming
  the exact unit that failed -- no partial, silently-incomplete run. This
  mirrors `GgenIgniter.SyncShellout`'s own real/error tuple discipline
  rather than swallowing a non-zero exit.

  After every unit succeeds, this task runs `mix compile
  --warnings-as-errors` once, then `mix test` scoped to the union of every
  unit's non-nil `test_path` (or a bare `mix test` with no test_path
  filter if no unit declares one).
  """
  use Mix.Task

  @shortdoc "Syncs every ggen_igniter generation unit in a manifest, then verifies"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [manifest: :string, unit: :string],
        aliases: [m: :manifest, u: :unit]
      )

    manifest_path = Keyword.get(opts, :manifest, "priv/ggen/manifest.json")
    only_unit = Keyword.get(opts, :unit)

    units =
      manifest_path
      |> load_manifest!()
      |> filter_units(only_unit)

    if units == [] do
      Mix.shell().info("mix ex4pm.ggen.sync: no generation units to run (manifest empty or --unit matched nothing).")
    else
      Enum.each(units, &sync_unit!/1)

      Mix.shell().info("mix ex4pm.ggen.sync: #{length(units)} unit(s) synced.")

      run_shell_step!("compile", ["compile", "--warnings-as-errors"])

      test_paths = units |> Enum.map(& &1["test_path"]) |> Enum.filter(& &1)

      if test_paths == [] do
        Mix.shell().info("mix ex4pm.ggen.sync: no unit declares a test_path; skipping mix test.")
      else
        run_shell_step!("test", ["test" | test_paths])
      end
    end
  end

  defp load_manifest!(path) do
    unless File.exists?(path) do
      Mix.raise("mix ex4pm.ggen.sync: manifest not found at #{path}")
    end

    case Jason.decode(File.read!(path)) do
      {:ok, units} when is_list(units) -> units
      {:ok, _other} -> Mix.raise("mix ex4pm.ggen.sync: manifest at #{path} must be a JSON array")
      {:error, reason} -> Mix.raise("mix ex4pm.ggen.sync: manifest at #{path} is not valid JSON: #{inspect(reason)}")
    end
  end

  defp filter_units(units, nil), do: units

  defp filter_units(units, unit_name) do
    case Enum.filter(units, &(&1["name"] == unit_name)) do
      [] -> Mix.raise("mix ex4pm.ggen.sync: no unit named #{inspect(unit_name)} in the manifest")
      matched -> matched
    end
  end

  defp run_shell_step!(label, mix_args) do
    env = if label == "test", do: [{"MIX_ENV", "test"}], else: []

    case System.cmd("mix", mix_args, stderr_to_stdout: true, env: env) do
      {output, 0} ->
        Mix.shell().info(output)

      {output, code} ->
        Mix.raise("mix ex4pm.ggen.sync: #{label} step failed (exit #{code}).\n\n#{output}")
    end
  end

  defp sync_unit!(%{"name" => name, "ontology" => ontology, "template" => template, "out" => out} = unit) do
    query_args =
      unit
      |> Map.get("query_bindings", %{})
      |> Enum.flat_map(fn {k, v} -> ["--query", "#{k}=#{v}"] end)

    cmd_args = ["ggen_igniter.sync", "--ontology", ontology] ++ query_args ++ ["--template", template, "--out", out]

    Mix.shell().info("mix ex4pm.ggen.sync: unit #{name} -> mix #{Enum.join(cmd_args, " ")}")

    case System.cmd("mix", cmd_args, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)

      {output, code} ->
        Mix.raise(
          "mix ex4pm.ggen.sync: FAILED at unit #{name} (exit #{code}). Aborting -- no further units were synced.\n\n#{output}"
        )
    end
  end
end
