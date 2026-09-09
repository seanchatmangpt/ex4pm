defmodule Ex4pmEngine.Wasm.Mean do
  @moduledoc """
  wasm4pm-ex4pm-bindings `mean` adapter -- Phase 4 (statistics/ML),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase4_stats.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:mean_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :mean,
    engine_id: :wasm_mean,
    wasm_export: "wasm4pm_ex4pm_mean_v1",
    wasm_replay_export: "wasm4pm_ex4pm_mean_replay_v1"
end
