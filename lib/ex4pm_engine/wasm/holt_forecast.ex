defmodule Ex4pmEngine.Wasm.HoltForecast do
  @moduledoc """
  wasm4pm-ex4pm-bindings `holt_forecast` adapter -- Phase 4 (statistics/ML),
  thin wrapper over an already-implemented, plain (non-wasm_bindgen) pub
  fn already present in the `wasm4pm` crate. See
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase4_stats.rs` for the
  real Rust implementation this binds.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:holt_forecast_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :holt_forecast,
    engine_id: :wasm_holt_forecast,
    wasm_export: "wasm4pm_ex4pm_holt_forecast_v1",
    wasm_replay_export: "wasm4pm_ex4pm_holt_forecast_replay_v1"
end
