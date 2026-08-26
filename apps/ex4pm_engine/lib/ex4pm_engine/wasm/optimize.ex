defmodule Ex4pmEngine.Wasm.Optimize do
  @moduledoc """
  wasm4pm-ex4pm-bindings DAG longest-path (critical path) optimization adapter.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:optimize_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :optimize,
    engine_id: :wasm_optimize,
    wasm_export: "wasm4pm_ex4pm_optimize_v1",
    wasm_replay_export: "wasm4pm_ex4pm_optimize_replay_v1"
end
