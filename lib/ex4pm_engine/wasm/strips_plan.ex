defmodule Ex4pmEngine.Wasm.StripsPlan do
  @moduledoc """
  wasm4pm-ex4pm-bindings `strips_plan` adapter -- Phase 2 (thin wrappers over
  miniml/ocpq/wasm4pm-cognition), thin wrapper over an already-implemented,
  plain (non-wasm_bindgen) pub fn already present in the `wasm4pm` crate.
  See `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase2.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:strips_plan_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :strips_plan,
    engine_id: :wasm_strips_plan,
    wasm_export: "wasm4pm_ex4pm_strips_plan_v1",
    wasm_replay_export: "wasm4pm_ex4pm_strips_plan_replay_v1"
end
