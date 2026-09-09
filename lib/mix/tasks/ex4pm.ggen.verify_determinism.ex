defmodule Mix.Tasks.Ex4pm.Ggen.VerifyDeterminism do
  @moduledoc """
  Verifies that a ggen generation unit (ontology + query/queries + template -> out file)
  produces byte-identical output when regenerated -- turns the PRD's "proven manually
  (delete, regenerate, diff byte-identical)" one-time narration into a real, automated,
  repeatable gate wired into `mix verify`.

  ## Single unit

      mix ex4pm.ggen.verify_determinism \\
        --ontology priv/ggen/units/standing_coded/ontology.ttl \\
        --query standings=priv/ggen/units/standing_coded/standings.rq \\
        --template priv/ggen/templates/standing_coded.ex.eex \\
        --out lib/ex4pm/standing/coded.ex

  `--query` is repeatable: `--query name=path.rq`.

  ## All units in the manifest

      mix ex4pm.ggen.verify_determinism --all

  Reads `priv/ggen/manifest.json` (or `--manifest <path>`) and verifies every unit
  listed in it, printing a summary table. If the manifest doesn't exist, `--all` exits
  0 (no-op) rather than failing -- a sibling worktree may not have merged it yet.

  Exits 1 (non-zero) if any unit's regenerated output differs from the checked-in
  `--out` file, naming the exact differing lines.
  """

  use Mix.Task

  @shortdoc "Verifies ggen-generated files are byte-identical on regeneration"

  @default_manifest "priv/ggen/manifest.json"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start", ["--no-start"])

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          ontology: :string,
          template: :string,
          out: :string,
          all: :boolean,
          manifest: :string,
          query: [:string, :keep]
        ]
      )

    cond do
      opts[:all] ->
        run_all(opts[:manifest] || @default_manifest)

      opts[:ontology] && opts[:template] && opts[:out] ->
        queries = parse_queries(Keyword.get_values(opts, :query))

        unit = %{
          name: opts[:out],
          ontology: opts[:ontology],
          queries: queries,
          template: opts[:template],
          out: opts[:out]
        }

        [result] = [verify_unit(unit)]
        report_and_exit([result])

      true ->
        Mix.shell().error(
          "Usage: mix ex4pm.ggen.verify_determinism --ontology <path> --query name=path.rq " <>
            "--template <path> --out <path> (repeatable --query), or --all"
        )

        exit({:shutdown, 1})
    end
  end

  defp parse_queries(raw) do
    Enum.reduce(raw, %{}, fn entry, acc ->
      case String.split(entry, "=", parts: 2) do
        [name, path] -> Map.put(acc, name, path)
        _ -> Mix.raise("invalid --query value #{inspect(entry)}, expected name=path.rq")
      end
    end)
  end

  defp run_all(manifest_path) do
    if File.exists?(manifest_path) do
      manifest = manifest_path |> File.read!() |> Jason.decode!()

      results =
        Enum.map(manifest["units"] || [], fn unit ->
          verify_unit(%{
            name: unit["name"],
            ontology: unit["ontology"],
            queries: unit["queries"] || %{},
            template: unit["template"],
            out: unit["out"]
          })
        end)

      report_and_exit(results, summary_table?: true)
    else
      Mix.shell().info(
        "ex4pm.ggen.verify_determinism --all: no #{manifest_path} present, no-op (0 units checked)"
      )
    end
  end

  # Returns {:ok, name} | {:mismatch, name, diff_lines} | {:error, name, reason}
  defp verify_unit(unit) do
    name = unit.name || unit.out

    before =
      case File.read(unit.out) do
        {:ok, content} -> content
        {:error, _} -> nil
      end

    scratch =
      Path.join(System.tmp_dir!(), "ex4pm_ggen_verify_#{:erlang.unique_integer([:positive])}")

    generation_unit = %{
      ontology: unit.ontology,
      queries: unit.queries,
      template: unit.template,
      out: unit.out
    }

    case Ex4pm.Ggen.Generator.render(generation_unit, scratch) do
      {:ok, regenerated} ->
        File.rm(scratch)

        cond do
          is_nil(before) ->
            {:error, name, "#{unit.out} does not exist (nothing to compare against)"}

          before == regenerated ->
            {:ok, name}

          true ->
            {:mismatch, name, diff_lines(before, regenerated)}
        end

      {:error, reason} ->
        File.rm(scratch)
        {:error, name, inspect(reason)}
    end
  end

  defp diff_lines(before, after_) do
    before_lines = String.split(before, "\n")
    after_lines = String.split(after_, "\n")
    max_len = max(length(before_lines), length(after_lines))

    Enum.reduce(0..(max_len - 1), [], fn i, acc ->
      b = Enum.at(before_lines, i)
      a = Enum.at(after_lines, i)

      if b != a do
        ["line #{i + 1}: checked-in=#{inspect(b)} regenerated=#{inspect(a)}" | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end

  defp report_and_exit(results, opts \\ []) do
    if Keyword.get(opts, :summary_table?, false) do
      Mix.shell().info("ggen determinism summary:")
      Mix.shell().info(String.pad_trailing("unit", 30) <> "deterministic?")
      Mix.shell().info(String.duplicate("-", 46))

      Enum.each(results, fn
        {:ok, name} ->
          Mix.shell().info(String.pad_trailing(to_string(name), 30) <> "yes")

        {:mismatch, name, _} ->
          Mix.shell().info(String.pad_trailing(to_string(name), 30) <> "NO (mismatch)")

        {:error, name, _} ->
          Mix.shell().info(String.pad_trailing(to_string(name), 30) <> "NO (error)")
      end)
    end

    failures = Enum.reject(results, &match?({:ok, _}, &1))

    Enum.each(results, fn
      {:ok, name} ->
        Mix.shell().info("deterministic: #{name}")

      {:mismatch, name, diff} ->
        Mix.shell().error("NOT deterministic: #{name}")
        Enum.each(diff, &Mix.shell().error("  #{&1}"))

      {:error, name, reason} ->
        Mix.shell().error("could not verify: #{name} (#{reason})")
    end)

    if failures != [] do
      exit({:shutdown, 1})
    end
  end
end
