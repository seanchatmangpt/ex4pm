defmodule Ex4pmEngine.Wasm.EtcPrecision do
  @moduledoc """
  wasm4pm-ex4pm-bindings `etc_precision` adapter -- Phase 2 (process mining core),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase2.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:etc_precision_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :etc_precision,
    engine_id: :wasm_etc_precision,
    wasm_export: "wasm4pm_ex4pm_etc_precision_v1",
    wasm_replay_export: "wasm4pm_ex4pm_etc_precision_replay_v1"
end
