defmodule Ex4pmEngine.Wasm.Playout do
  @moduledoc """
  wasm4pm-ex4pm-bindings `playout` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `wasm4pm`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:playout_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :playout,
    engine_id: :wasm_playout,
    wasm_export: "wasm4pm_ex4pm_playout_v1",
    wasm_replay_export: "wasm4pm_ex4pm_playout_replay_v1"
end
