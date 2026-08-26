defmodule Ex4pmEngine.Wasm.CtlCheck do
  @moduledoc """
  wasm4pm-ex4pm-bindings `ctl_check` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `wasm4pm-cognition`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:ctl_check_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :ctl_check,
    engine_id: :wasm_ctl_check,
    wasm_export: "wasm4pm_ex4pm_ctl_check_v1",
    wasm_replay_export: "wasm4pm_ex4pm_ctl_check_replay_v1"
end
