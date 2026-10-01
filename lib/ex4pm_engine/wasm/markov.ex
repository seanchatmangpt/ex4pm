defmodule Ex4pmEngine.Wasm.Markov do
  @moduledoc """
  wasm4pm-ex4pm-bindings `markov` adapter -- hand-written, not
  generated. Thin wrapper over an already-implemented, plain
  (non-wasm_bindgen) pub fn already present in the `miniml-core`
  crate. See `~/wasm4pm/crates/miniml-core` for the real Rust
  implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:markov_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :markov,
    engine_id: :wasm_markov,
    wasm_export: "wasm4pm_ex4pm_markov_v1",
    wasm_replay_export: "wasm4pm_ex4pm_markov_replay_v1"
end
