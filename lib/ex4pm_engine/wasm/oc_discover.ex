defmodule Ex4pmEngine.Wasm.OcDiscover do
  @moduledoc """
  wasm4pm-ex4pm-bindings `oc_discover` adapter -- Phase 2 (process mining core),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase2.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:oc_discover_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :oc_discover,
    engine_id: :wasm_oc_discover,
    wasm_export: "wasm4pm_ex4pm_oc_discover_v1",
    wasm_replay_export: "wasm4pm_ex4pm_oc_discover_replay_v1"
end
