defmodule Mix.Tasks.Ex4pm.Engine.Gen.Adapter do
  @moduledoc """
  Regenerates the pack-generated WASM leaf adapters
  (`Ex4pmEngine.Wasm.<Id>`) by running real `ggen sync run` in the ggen
  consumer directory (`ggen/bindings` by default), which binds
  `ex4pm-wasm4pm-bindings-pack` (one `epm:AlgorithmBinding` row per leaf,
  rendered through `elixir_adapter.tmpl`).

      mix ex4pm.engine.gen.adapter
      mix ex4pm.engine.gen.adapter --dir ggen/bindings

  Output lands in `<dir>/lib/ex4pm_engine/wasm/<algorithm_id>.ex`. Adding a
  new leaf means adding an `epm:AlgorithmBinding` to the pack ontology, not
  hand-writing an adapter; leaves without a binding carry a
  `# not pack-generated` marker in their moduledoc.

  Refusals (raised via `Mix.raise/1`, typed in the message prefix):

    * `REFUSED_NO_CONSUMER` -- the consumer dir has no `ggen.toml`
      (see `mix ex4pm.ggen.sync` for manifest-driven sync).
    * `REFUSED_NO_GGEN` -- no `ggen` executable on PATH.
    * `REFUSED_SYNC_FAILED` -- `ggen sync run` exited non-zero.
  """
  use Mix.Task

  @shortdoc "Regenerates pack-generated WASM leaf adapters via ggen sync"

  @default_dir "ggen/bindings"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [dir: :string])
    dir = Keyword.get(opts, :dir, @default_dir)

    unless File.regular?(Path.join(dir, "ggen.toml")) do
      Mix.raise("""
      REFUSED_NO_CONSUMER: #{dir}/ggen.toml not found. The ggen consumer for
      ex4pm-wasm4pm-bindings-pack has not been created here; see
      `mix ex4pm.ggen.sync` for manifest-driven generation.
      """)
    end

    ggen =
      System.find_executable("ggen") ||
        Mix.raise("REFUSED_NO_GGEN: no `ggen` executable on PATH.")

    {out, status} = System.cmd(ggen, ["sync", "run"], cd: dir, stderr_to_stdout: true)

    if status != 0 do
      Mix.raise("REFUSED_SYNC_FAILED: ggen sync run exited #{status} in #{dir}\n#{out}")
    end

    Mix.shell().info("mix ex4pm.engine.gen.adapter: ggen sync run ok in #{dir}")
    :ok
  end
end
