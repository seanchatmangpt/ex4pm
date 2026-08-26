defmodule Ex4pmEngine.Wasm.Discover do
  @moduledoc """
  wasm4pm-ex4pm-bindings directly-follows-graph discovery adapter.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:discover_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :discover,
    engine_id: :wasm_discover,
    wasm_export: "wasm4pm_ex4pm_discover_v1",
    wasm_replay_export: "wasm4pm_ex4pm_discover_replay_v1"
end
