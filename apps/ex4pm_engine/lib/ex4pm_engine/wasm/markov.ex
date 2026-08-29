defmodule Ex4pmEngine.Wasm.Markov do
  @moduledoc """
  wasm4pm-ex4pm-bindings `markov` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `miniml-core`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:markov_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :markov,
    engine_id: :wasm_markov,
    wasm_export: "wasm4pm_ex4pm_markov_v1",
    wasm_replay_export: "wasm4pm_ex4pm_markov_replay_v1"
end
