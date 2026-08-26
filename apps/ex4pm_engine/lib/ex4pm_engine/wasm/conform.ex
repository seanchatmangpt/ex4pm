defmodule Ex4pmEngine.Wasm.Conform do
  @moduledoc """
  wasm4pm-ex4pm-bindings directly-follows fitness/conformance adapter.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:conform_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :conform,
    engine_id: :wasm_conform,
    wasm_export: "wasm4pm_ex4pm_conform_v1",
    wasm_replay_export: "wasm4pm_ex4pm_conform_replay_v1"
end
