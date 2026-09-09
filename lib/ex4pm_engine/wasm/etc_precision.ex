defmodule Ex4pmEngine.Wasm.EtcPrecision do
  @moduledoc """
  wasm4pm-ex4pm-bindings `etc_precision` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `wasm4pm`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:etc_precision_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :etc_precision,
    engine_id: :wasm_etc_precision,
    wasm_export: "wasm4pm_ex4pm_etc_precision_v1",
    wasm_replay_export: "wasm4pm_ex4pm_etc_precision_replay_v1"
end
