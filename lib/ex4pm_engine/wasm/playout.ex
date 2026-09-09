defmodule Ex4pmEngine.Wasm.Playout do
  @moduledoc """
  wasm4pm-ex4pm-bindings `playout` adapter -- Phase 2 (process mining core),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase2_playout.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:playout_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :playout,
    engine_id: :wasm_playout,
    wasm_export: "wasm4pm_ex4pm_playout_v1",
    wasm_replay_export: "wasm4pm_ex4pm_playout_replay_v1"
end
