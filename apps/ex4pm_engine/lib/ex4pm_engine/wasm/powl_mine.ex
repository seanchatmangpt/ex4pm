defmodule Ex4pmEngine.Wasm.PowlMine do
  @moduledoc """
  wasm4pm-ex4pm-bindings sequence/leaf/flower POWL base-case mining adapter.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:powl_mine_wasm_fun`. Introduces the `:powl_mine`
  operation atom to `Ex4pm.Engine` — not previously supported by
  `Ex4pm.Engine.Beam`, which exposes POWL mining only indirectly through
  `Ex4pmEngine.POWL`/`Ex4pmEngine.InductiveMiner` rather than as a selectable
  engine operation.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :powl_mine,
    engine_id: :wasm_powl_mine,
    wasm_export: "wasm4pm_ex4pm_powl_mine_v1",
    wasm_replay_export: "wasm4pm_ex4pm_powl_mine_replay_v1"
end
