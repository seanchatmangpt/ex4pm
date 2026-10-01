defmodule Mix.Tasks.Ex4pm.Ggen.Sync do
  @moduledoc """
  Runs every ggen_igniter generation unit declared in a manifest, then
  verifies the result -- replacing the bespoke per-consumer bash scripts
  (`scripts/standing_coded_sync.sh`) with one shared, general Mix task.

  Real, confirmed motivation (ERRC cluster c8, 2026-09-09 deep-search
  workflow): `scripts/standing_coded_sync.sh` hand-rolls "mix deps.get; N x
  mix ggen_igniter.sync calls; mix compile --warnings-as-errors; mix test"
  for exactly one consumer (`Ex4pm.Standing.Coded`); a separate repo's
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

  Optional per-unit fields:

    * `"extra_ontologies"` -- list of Turtle paths concatenated after
      `"ontology"` (fixed order) into one merged scratch TTL under
      `.ggen_igniter_tmp/` that is passed as the single `--ontology` (the
      merged file is never committed). Vendored packs live in
      `priv/ggen/vendor/` and are checked against `PACKS.lock.json`
      (sha256) before use; a mismatch refuses the unit.
    * `"gates"` -- list of SPARQL SELECT gate files run in-process against the
      merged graph before generation; any returned row refuses the unit.
    * `"vendor_lock"` -- lock path (default `priv/ggen/vendor/PACKS.lock.json`).

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

  @default_lock "priv/ggen/vendor/PACKS.lock.json"
  @tmp_dir ".ggen_igniter_tmp"

  @doc false
  # Shared with Mix.Tasks.Ex4pm.Ggen.VerifyDeterminism. Returns
  # `{:ok, effective_ontology, cleanup_fun}` or `{:error, message}`.
  # Units without "extra_ontologies" pass their ontology through unchanged.
  def prepare_ontology(%{"name" => name, "ontology" => ontology} = unit) do
    extras = Map.get(unit, "extra_ontologies", [])

    if extras == [] and Map.get(unit, "gates", []) == [] do
      {:ok, ontology, fn -> :ok end}
    else
      with :ok <- check_vendor_lock(unit),
           {:ok, merged} <- merge_ontologies(name, [ontology | extras]) do
        {:ok, merged, fn -> File.rm(merged) end}
      end
    end
  end

  @doc false
  # Every path in "extra_ontologies"/"gates" that lives under the lock's
  # directory must be listed in the lock with the same sha256.
  def check_vendor_lock(unit) do
    lock_path = Map.get(unit, "vendor_lock", @default_lock)
    paths = Map.get(unit, "extra_ontologies", []) ++ Map.get(unit, "gates", [])
    vendor_dir = Path.expand(Path.dirname(lock_path))

    vendored = Enum.filter(paths, &String.starts_with?(Path.expand(&1), vendor_dir <> "/"))

    cond do
      vendored == [] ->
        :ok

      not File.exists?(lock_path) ->
        {:error, "vendor lock #{lock_path} not found for vendored inputs #{inspect(vendored)}"}

      true ->
        lock = lock_path |> File.read!() |> Jason.decode!()

        locked =
          ((lock["packs"] || []) |> Enum.flat_map(& &1["files"])) ++ (lock["generated"] || [])

        locked = Map.new(locked, &{Path.expand(&1["path"], vendor_dir), &1["sha256"]})

        Enum.find_value(vendored, :ok, fn path ->
          expected = Map.get(locked, Path.expand(path))
          actual = if File.exists?(path), do: sha256(File.read!(path))

          cond do
            expected == nil -> {:error, "vendored input #{path} is not listed in #{lock_path}"}
            actual != expected -> {:error, "vendored input #{path} sha256 #{actual || "MISSING"} != locked #{expected} (#{lock_path}); re-run priv/ggen/vendor/sync.sh"}
            true -> nil
          end
        end)
    end
  end

  defp sha256(bin), do: :crypto.hash(:sha256, bin) |> Base.encode16(case: :lower)

  defp merge_ontologies(name, paths) do
    case Enum.reject(paths, &File.regular?/1) do
      [] ->
        merged = paths |> Enum.map(&File.read!/1) |> Enum.join("\n")
        File.mkdir_p!(@tmp_dir)
        out = Path.join(@tmp_dir, "merged_#{name}_#{:erlang.unique_integer([:positive])}.ttl")
        File.write!(out, merged)
        {:ok, out}

      missing ->
        {:error, "ontology input(s) not found: #{inspect(missing)}"}
    end
  end

  # Runs each gate in-process against the merged graph; any row refuses.
  defp run_gates(%{"gates" => gates} = unit, ontology) when gates != [] do
    Mix.Task.run("app.start")
    graph = GgenIgniter.Ontology.load!(ontology)

    failures =
      Enum.flat_map(gates, fn gate ->
        rows = GgenIgniter.Query.Oxigraph.run(graph, File.read!(gate))
        if rows == [], do: [], else: [{gate, rows}]
      end)

    case failures do
      [] ->
        Mix.shell().info("mix ex4pm.ggen.sync: unit #{unit["name"]}: #{length(gates)} gate(s) clean (zero rows).")
        :ok

      _ ->
        detail =
          Enum.map_join(failures, "\n", fn {gate, rows} ->
            "  gate #{gate}: #{length(rows)} row(s), first: #{inspect(hd(rows))}"
          end)

        {:error, "gate(s) refused:\n#{detail}"}
    end
  end

  defp run_gates(_unit, _ontology), do: :ok

  defp sync_unit!(%{"name" => name, "ontology" => _ontology, "template" => template, "out" => out} = unit) do
    {ontology, cleanup} =
      with {:ok, effective, cleanup} <- prepare_ontology(unit),
           :ok <- run_gates_or_cleanup(unit, effective, cleanup) do
        {effective, cleanup}
      else
        {:error, msg} ->
          Mix.raise(
            "mix ex4pm.ggen.sync: FAILED at unit #{name} (#{msg}). Aborting -- no further units were synced."
          )
      end

    query_args =
      unit
      |> Map.get("query_bindings", %{})
      |> Enum.flat_map(fn {k, v} -> ["--query", "#{k}=#{v}"] end)

    cmd_args = ["ggen_igniter.sync", "--ontology", ontology] ++ query_args ++ ["--template", template, "--out", out]

    Mix.shell().info("mix ex4pm.ggen.sync: unit #{name} -> mix #{Enum.join(cmd_args, " ")}")

    result = System.cmd("mix", cmd_args, stderr_to_stdout: true)
    cleanup.()

    case result do
      {output, 0} ->
        Mix.shell().info(output)

      {output, code} ->
        Mix.raise(
          "mix ex4pm.ggen.sync: FAILED at unit #{name} (exit #{code}). Aborting -- no further units were synced.\n\n#{output}"
        )
    end
  end

  defp run_gates_or_cleanup(unit, effective, cleanup) do
    case run_gates(unit, effective) do
      :ok ->
        :ok

      {:error, _} = err ->
        cleanup.()
        err
    end
  end
end
