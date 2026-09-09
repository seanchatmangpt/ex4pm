defmodule Ex4pmEngine.Wasm.Soundness do
  @moduledoc """
  wasm4pm-ex4pm-bindings `soundness` adapter -- Phase 2 (process mining core),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase2.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:soundness_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :soundness,
    engine_id: :wasm_soundness,
    wasm_export: "wasm4pm_ex4pm_soundness_v1",
    wasm_replay_export: "wasm4pm_ex4pm_soundness_replay_v1"
end
