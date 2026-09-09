defmodule Ex4pmEngine.Wasm.OcpqEval do
  @moduledoc """
  wasm4pm-ex4pm-bindings `ocpq_eval` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `ocpq`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:ocpq_eval_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :ocpq_eval,
    engine_id: :wasm_ocpq_eval,
    wasm_export: "wasm4pm_ex4pm_ocpq_eval_v1",
    wasm_replay_export: "wasm4pm_ex4pm_ocpq_eval_replay_v1"
end
