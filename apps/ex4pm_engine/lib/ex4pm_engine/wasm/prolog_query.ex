defmodule Ex4pmEngine.Wasm.PrologQuery do
  @moduledoc """
  wasm4pm-ex4pm-bindings `prolog_query` adapter — generated from
  `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`, source crate
  `prolog8`.

  See `Ex4pmEngine.Wasm.Adapter` for the shared six-state standing shape.
  Injected transport key: `:prolog_query_wasm_fun`.
  """

  use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :prolog_query,
    engine_id: :wasm_prolog_query,
    wasm_export: "wasm4pm_ex4pm_prolog_query_v1",
    wasm_replay_export: "wasm4pm_ex4pm_prolog_query_replay_v1"
end
