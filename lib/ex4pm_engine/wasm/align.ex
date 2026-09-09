defmodule Ex4pmEngine.Wasm.Align do
  @moduledoc """
  wasm4pm-ex4pm-bindings `align` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `wasm4pm`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:align_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :align,
    engine_id: :wasm_align,
    wasm_export: "wasm4pm_ex4pm_align_v1",
    wasm_replay_export: "wasm4pm_ex4pm_align_replay_v1"
end
