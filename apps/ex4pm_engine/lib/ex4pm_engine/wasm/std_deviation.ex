defmodule Ex4pmEngine.Wasm.StdDeviation do
  @moduledoc """
  wasm4pm-ex4pm-bindings `std_deviation` adapter -- Phase 4 (statistics/ML),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase4_stats.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:std_deviation_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :std_deviation,
    engine_id: :wasm_std_deviation,
    wasm_export: "wasm4pm_ex4pm_std_deviation_v1",
    wasm_replay_export: "wasm4pm_ex4pm_std_deviation_replay_v1"
end
