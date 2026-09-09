defmodule Ex4pmEngine.Wasm.AllenTemporal do
  @moduledoc """
  wasm4pm-ex4pm-bindings `allen_temporal` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `wasm4pm-cognition`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:allen_temporal_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :allen_temporal,
    engine_id: :wasm_allen_temporal,
    wasm_export: "wasm4pm_ex4pm_allen_temporal_v1",
    wasm_replay_export: "wasm4pm_ex4pm_allen_temporal_replay_v1"
end
