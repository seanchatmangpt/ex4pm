defmodule Ex4pmEngine.Wasm.PowlMine do
  @moduledoc """
  wasm4pm-ex4pm-bindings `powl_mine` adapter -- hand-written, not
  generated. Thin wrapper over an already-implemented, plain
  (non-wasm_bindgen) pub fn already present in the `wasm4pm-ex4pm-bindings`
  crate. See `~/wasm4pm/crates/wasm4pm-ex4pm-bindings` for the real Rust
  implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:powl_mine_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :powl_mine,
    engine_id: :wasm_powl_mine,
    wasm_export: "wasm4pm_ex4pm_powl_mine_v1",
    wasm_replay_export: "wasm4pm_ex4pm_powl_mine_replay_v1"
end
