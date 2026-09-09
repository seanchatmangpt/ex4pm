defmodule Ex4pmEngine.Wasm.Survival do
  @moduledoc """
  wasm4pm-ex4pm-bindings `survival` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `miniml-core`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:survival_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :survival,
    engine_id: :wasm_survival,
    wasm_export: "wasm4pm_ex4pm_survival_v1",
    wasm_replay_export: "wasm4pm_ex4pm_survival_replay_v1"
end
