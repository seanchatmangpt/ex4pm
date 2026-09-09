defmodule Ex4pmEngine.Wasm.OcDiscover do
  @moduledoc """
  wasm4pm-ex4pm-bindings `oc_discover` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `wasm4pm`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:oc_discover_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :oc_discover,
    engine_id: :wasm_oc_discover,
    wasm_export: "wasm4pm_ex4pm_oc_discover_v1",
    wasm_replay_export: "wasm4pm_ex4pm_oc_discover_replay_v1"
end
