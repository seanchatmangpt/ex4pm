defmodule Ex4pmEngine.Wasm.Simulate do
  @moduledoc """
  wasm4pm-ex4pm-bindings deterministic seeded-walk simulation adapter.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:simulate_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :simulate,
    engine_id: :wasm_simulate,
    wasm_export: "wasm4pm_ex4pm_simulate_v1",
    wasm_replay_export: "wasm4pm_ex4pm_simulate_replay_v1"
end
