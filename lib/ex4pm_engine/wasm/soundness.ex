defmodule Ex4pmEngine.Wasm.Soundness do
  @moduledoc """
  wasm4pm-ex4pm-bindings `soundness` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `wasm4pm`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:soundness_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :soundness,
    engine_id: :wasm_soundness,
    wasm_export: "wasm4pm_ex4pm_soundness_v1",
    wasm_replay_export: "wasm4pm_ex4pm_soundness_replay_v1"
end
