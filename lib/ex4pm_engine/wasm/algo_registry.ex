defmodule Ex4pmEngine.Wasm.AlgoRegistry do
  @moduledoc """
  Canonical registry of WASM-backed algorithm adapters for `Ex4pm.Engine.Wasm`.

  Each entry names an `algorithm_id` (an atom, also used as the generated
  adapter module's file basename under `lib/ex4pm_engine/wasm/`) and the
  `export` symbol the admitted WASM artifact exposes for it. New entries are
  added by generating an adapter module with
  `mix ex4pm.engine.gen.adapter <algorithm_id>` (see
  `Mix.Tasks.Ex4pm.Engine.Gen.Adapter`), following the pattern established by
  `Ex4pmEngine.Wasm.Mean`.

  Registration is deliberately narrower than the adapter module count: 33 leaf
  adapter modules exist under `lib/ex4pm_engine/wasm/`, but `@specs` below
  currently registers only `:mean`. An adapter module existing on disk is not
  the same claim as it being registered here; do not read the module count as
  registry coverage.
  """

  @type spec :: %{algorithm_id: atom(), export: String.t()}

  @specs [
    %{algorithm_id: :mean, export: "mean"}
  ]

  @spec algo_specs() :: [spec()]
  def algo_specs, do: @specs
end
