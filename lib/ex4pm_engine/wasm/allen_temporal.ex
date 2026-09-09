defmodule Ex4pmEngine.Wasm.AllenTemporal do
  @moduledoc """
  wasm4pm-ex4pm-bindings `allen_temporal` adapter -- Phase 2 (process mining core),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase2.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:allen_temporal_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :allen_temporal,
    engine_id: :wasm_allen_temporal,
    wasm_export: "wasm4pm_ex4pm_allen_temporal_v1",
    wasm_replay_export: "wasm4pm_ex4pm_allen_temporal_replay_v1"
end
