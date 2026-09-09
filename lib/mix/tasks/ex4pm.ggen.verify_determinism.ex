defmodule Mix.Tasks.Ex4pm.Ggen.VerifyDeterminism do
  @moduledoc """
  Proves a ggen_igniter generation unit is a deterministic, pure function
  of `(ontology, query, template)` -- by actually regenerating it into a
  scratch path and byte-diffing against the checked-in output -- instead
  of a one-time narrated "I deleted it and regenerated it and it matched"
  claim.

  Real, confirmed motivation (ERRC cluster c3, 2026-09-09 deep-search
  workflow): ggen's Rust core (`~/ggen`) generates its own quality/status
  artifacts (CONSTITUTION.md, VERIFICATION.md) as checked-in, admitted,
  provable output. ex4pm's own `docs/PRD-v26.9.10.md` states its
  determinism claim for generated files is "proven manually (delete,
  regenerate, diff byte-identical)" -- not wired into `mix verify` or any
  sync script. This task closes that gap.

  ## Usage

      mix ex4pm.ggen.verify_determinism --ontology priv/ontology/ex4pm.ttl \\
        --query admitted=priv/ggen/queries/admitted_standing_codes.rq \\
        --template priv/ggen/templates/standing_coded.ex.eex \\
        --out lib/ex4pm/standing_coded.ex

      mix ex4pm.ggen.verify_determinism --all
      mix ex4pm.ggen.verify_determinism --all --manifest priv/ggen/manifest.json

  `--all` reads every unit from `priv/ggen/manifest.json` (or
  `--manifest PATH`) and verifies each, printing a summary table. If the
  manifest doesn't exist, `--all` no-ops with a clear message (exit 0)
  rather than failing -- so `mix verify` can call this unconditionally
  without requiring every consumer repo to have a manifest yet.

  ## Exit behavior

  Exits 0 with `"deterministic: <out>"` per matching unit. Exits 1 naming
  the exact unit and a real diff summary on any mismatch -- never silently
  passes a divergent unit.
  """
  use Mix.Task

  @shortdoc "Proves a ggen_igniter generation unit regenerates byte-identically"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [ontology: :string, query: :keep, template: :string, out: :string, all: :boolean, manifest: :string],
        aliases: [o: :ontology, t: :template]
      )

    cond do
      Keyword.get(opts, :all, false) ->
        run_all(Keyword.get(opts, :manifest, "priv/ggen/manifest.json"))

      Keyword.get(opts, :ontology) && Keyword.get(opts, :template) && Keyword.get(opts, :out) ->
        unit = %{
          "name" => Keyword.get(opts, :out),
          "ontology" => Keyword.fetch!(opts, :ontology),
          "query_bindings" => parse_query_opts(opts),
          "template" => Keyword.fetch!(opts, :template),
          "out" => Keyword.fetch!(opts, :out)
        }

        case verify_unit(unit) do
          {:ok, msg} -> Mix.shell().info(msg)
          {:error, msg} -> Mix.raise(msg)
        end

      true ->
        Mix.raise(
          "mix ex4pm.ggen.verify_determinism: pass --ontology/--query/--template/--out for one unit, or --all for every manifest unit."
        )
    end
  end

  defp parse_query_opts(opts) do
    opts
    |> Keyword.get_values(:query)
    |> Enum.map(fn kv ->
      [k, v] = String.split(kv, "=", parts: 2)
      {k, v}
    end)
    |> Map.new()
  end

  defp run_all(manifest_path) do
    unless File.exists?(manifest_path) do
      Mix.shell().info(
        "mix ex4pm.ggen.verify_determinism --all: no manifest at #{manifest_path}, nothing to verify (not a failure)."
      )
    else
      units =
        manifest_path
        |> File.read!()
        |> Jason.decode!()

      results = Enum.map(units, fn unit -> {unit["name"], verify_unit(unit)} end)

      Mix.shell().info("\nDeterminism verification summary:\n")

      Enum.each(results, fn
        {name, {:ok, _}} -> Mix.shell().info("  deterministic  #{name}")
        {name, {:error, _}} -> Mix.shell().error("  DIVERGENT      #{name}")
      end)

      failures = Enum.filter(results, fn {_name, r} -> match?({:error, _}, r) end)

      if failures != [] do
        details = Enum.map_join(failures, "\n\n", fn {_name, {:error, msg}} -> msg end)
        Mix.raise("\nmix ex4pm.ggen.verify_determinism --all: #{length(failures)} unit(s) diverged.\n\n#{details}")
      end
    end
  end

  defp verify_unit(%{"name" => name, "ontology" => ontology, "template" => template, "out" => out} = unit) do
    unless File.exists?(out) do
      throw_or_error(name, "checked-in output #{out} does not exist -- run mix ex4pm.ggen.sync first")
    else
      checked_in = File.read!(out)

      # ggen_igniter refuses to write outside the authorized project root
      # (a real, confirmed authority boundary -- see
      # Mix.Tasks.GgenIgniter.Sync.dispatch_reactor_reconcile/2), so the
      # scratch target must live inside the project, under the same
      # .ggen_igniter_tmp/ directory this repo's .gitignore already
      # excludes.
      scratch_dir = Path.join(File.cwd!(), ".ggen_igniter_tmp")
      File.mkdir_p!(scratch_dir)

      scratch_out =
        Path.join(scratch_dir, "verify_determinism_#{:erlang.unique_integer([:positive])}#{Path.extname(out)}")

      query_args =
        unit
        |> Map.get("query_bindings", %{})
        |> Enum.flat_map(fn {k, v} -> ["--query", "#{k}=#{v}"] end)

      cmd_args =
        ["ggen_igniter.sync", "--ontology", ontology] ++
          query_args ++ ["--template", template, "--out", scratch_out]

      case System.cmd("mix", cmd_args, stderr_to_stdout: true) do
        {_output, 0} ->
          regenerated = File.read!(scratch_out)
          File.rm(scratch_out)

          if regenerated == checked_in do
            {:ok, "deterministic: #{out}"}
          else
            {:error, diff_error(name, out, checked_in, regenerated)}
          end

        {output, code} ->
          File.rm(scratch_out)
          {:error, "unit #{name}: regeneration failed (exit #{code}) while verifying #{out}:\n\n#{output}"}
      end
    end
  end

  defp throw_or_error(name, msg), do: {:error, "unit #{name}: #{msg}"}

  defp diff_error(name, out, checked_in, regenerated) do
    checked_lines = String.split(checked_in, "\n")
    regen_lines = String.split(regenerated, "\n")

    first_diff_index =
      Enum.zip(checked_lines, regen_lines)
      |> Enum.find_index(fn {a, b} -> a != b end)

    detail =
      case first_diff_index do
        nil ->
          "line counts differ: checked-in has #{length(checked_lines)} lines, regenerated has #{length(regen_lines)} lines"

        idx ->
          "first differing line #{idx + 1}:\n  checked-in:   #{Enum.at(checked_lines, idx) |> inspect()}\n  regenerated:  #{Enum.at(regen_lines, idx) |> inspect()}"
      end

    "unit #{name}: #{out} is NOT deterministic -- checked-in content diverges from a fresh regeneration.\n#{detail}"
  end
end
