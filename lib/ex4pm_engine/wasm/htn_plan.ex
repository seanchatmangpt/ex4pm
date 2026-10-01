defmodule Ex4pmEngine.Wasm.HtnPlan do
  @moduledoc """
  wasm4pm-ex4pm-bindings `htn_plan` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `wasm4pm-cognition`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:htn_plan_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :htn_plan,
    engine_id: :wasm_htn_plan,
    wasm_export: "wasm4pm_ex4pm_htn_plan_v1",
    wasm_replay_export: "wasm4pm_ex4pm_htn_plan_replay_v1"
end
