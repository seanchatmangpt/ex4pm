defmodule Ex4pmEngine.Wasm.Bayesian do
  @moduledoc """
  wasm4pm-ex4pm-bindings `bayesian` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `miniml-core`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:bayesian_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :bayesian,
    engine_id: :wasm_bayesian,
    wasm_export: "wasm4pm_ex4pm_bayesian_v1",
    wasm_replay_export: "wasm4pm_ex4pm_bayesian_replay_v1"
end
