defmodule Ex4pmEngine.Wasm.HtnPlan do
  @moduledoc """
  wasm4pm-ex4pm-bindings `htn_plan` adapter -- Phase 2 (process mining core),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase2.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:htn_plan_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :htn_plan,
    engine_id: :wasm_htn_plan,
    wasm_export: "wasm4pm_ex4pm_htn_plan_v1",
    wasm_replay_export: "wasm4pm_ex4pm_htn_plan_replay_v1"
end
