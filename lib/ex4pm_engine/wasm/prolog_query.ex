defmodule Ex4pmEngine.Wasm.PrologQuery do
  @moduledoc """
  wasm4pm-ex4pm-bindings `prolog_query` adapter -- Phase 2 (process mining core),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `prolog8` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/prolog.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:prolog_query_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :prolog_query,
    engine_id: :wasm_prolog_query,
    wasm_export: "wasm4pm_ex4pm_prolog_query_v1",
    wasm_replay_export: "wasm4pm_ex4pm_prolog_query_replay_v1"
end
