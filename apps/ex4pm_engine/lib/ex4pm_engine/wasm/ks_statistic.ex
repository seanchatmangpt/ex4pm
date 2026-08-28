defmodule Ex4pmEngine.Wasm.KsStatistic do
  @moduledoc """
  wasm4pm-ex4pm-bindings `ks_statistic` adapter -- Phase 4 (statistics/ML),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase4_stats.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:ks_statistic_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :ks_statistic,
    engine_id: :wasm_ks_statistic,
    wasm_export: "wasm4pm_ex4pm_ks_statistic_v1",
    wasm_replay_export: "wasm4pm_ex4pm_ks_statistic_replay_v1"
end
