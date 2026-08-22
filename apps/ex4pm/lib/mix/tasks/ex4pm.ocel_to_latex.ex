defmodule Mix.Tasks.Ex4pm.OcelToLatex do
  @moduledoc """
  Exports publication-ready LaTeX tables from an IEEE OCEL 2.0 NDJSON file.

  ## Usage

      mix ex4pm.ocel_to_latex [path_to_ocel_ndjson] [--output path/to/output.tex]

  ## Example

      mix ex4pm.ocel_to_latex /Users/sac/xaas/priv/ocel/ash-actions.ndjson --output docs/thesis/chapters/generated_ocel_benchmark_tables.tex
  """

  use Mix.Task

  @shortdoc "Exports IEEE OCEL 2.0 benchmark metrics to LaTeX tables"

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args,
        switches: [output: :string],
        aliases: [o: :output]
      )

    input_path =
      case positional do
        [path | _] -> path
        [] -> "/Users/sac/xaas/priv/ocel/ash-actions.ndjson"
      end

    output_path =
      Keyword.get(opts, :output, "docs/thesis/chapters/generated_ocel_benchmark_tables.tex")

    Mix.shell().info("==> Ingesting IEEE OCEL 2.0 log: #{input_path}")
    {:ok, content} = Ex4pmEngine.OcelToLatex.export_latex(input_path, output: output_path)

    Mix.shell().info("==> Successfully generated LaTeX tables at: #{output_path}")
    Mix.shell().info("==> Output byte size: #{byte_size(content)} bytes")
  end
end
