defmodule Ex4pmEngine.Wasm.DotProduct do
  @moduledoc """
  wasm4pm-ex4pm-bindings `dot_product` adapter -- Phase 4 (statistics/ML),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase4_stats.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:dot_product_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :dot_product,
    engine_id: :wasm_dot_product,
    wasm_export: "wasm4pm_ex4pm_dot_product_v1",
    wasm_replay_export: "wasm4pm_ex4pm_dot_product_replay_v1"
end
