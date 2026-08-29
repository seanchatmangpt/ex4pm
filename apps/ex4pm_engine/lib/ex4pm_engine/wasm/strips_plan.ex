defmodule Ex4pmEngine.Wasm.StripsPlan do
  @moduledoc """
  wasm4pm-ex4pm-bindings `strips_plan` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `wasm4pm-cognition`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:strips_plan_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :strips_plan,
    engine_id: :wasm_strips_plan,
    wasm_export: "wasm4pm_ex4pm_strips_plan_v1",
    wasm_replay_export: "wasm4pm_ex4pm_strips_plan_replay_v1"
end
