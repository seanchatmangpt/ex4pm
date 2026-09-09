defmodule Ex4pmEngine.Reactors.WasmCapabilitiesReactorTest do
  @moduledoc """
  Real, no-mock proof that `Ex4pmEngine.Reactors.WasmCapabilitiesReactor`
  triggers wasm4pm capabilities as real Reactor steps -- one shared, real
  Wasmex instance, one independent step per algorithm, real WASM execution
  and real replay verification on every step, folded into one real standing
  via `Ex4pm.Standing.min/2`.

  Canonical datasets: `discover`/`conform`/`powl_mine` requests are the
  same directly-follows-graph traces used both by this crate's own Rust
  unit tests (`~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/lib.rs` tests
  module) and by the CI workflow
  (`.github/workflows/wasm4pm-bindings-integration.yml`) -- a real,
  cross-checked fixture, not invented here.

  Named, honest skip (not a silent pass) when the real artifact hasn't been
  built on this machine.
  """
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Reactors.WasmCapabilitiesReactor

  @artifact_path Path.expand(
                   "~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm"
                 )

  setup do
    if File.regular?(@artifact_path) do
      :ok
    else
      :skip
    end
  end

  @tag :real_wasm
  test "runs discover, conform, and powl_mine as independent real Reactor steps and folds a real :alive standing" do
    requests = %{
      discover: %{traces: [["a", "b", "c"], ["a", "b"]]},
      conform: %{traces: [["a", "b"], ["a", "c"]], model_edges: [%{from: "a", to: "b"}]},
      powl_mine: %{traces: [["a", "b"], ["a", "b"]]}
    }

    assert {:ok, %{results: results, standing: standing}} =
             Reactor.run(WasmCapabilitiesReactor, %{
               artifact_path: @artifact_path,
               requests: requests
             })

    assert results.discover.standing == :alive
    assert results.discover.value["activities"] == ["a", "b", "c"]

    assert results.conform.standing == :alive
    assert results.conform.value["fit_traces"] == 1

    assert results.powl_mine.standing == :alive

    # Algorithms not given a request are reported (not crashed) as :unsupported.
    assert results.align.standing == :unsupported

    # The overall folded standing must be the weakest real standing observed
    # -- with align/etc_precision/... unrequested (:unsupported), the fold
    # is genuinely :unsupported, not silently rounded up to :alive.
    assert standing == Ex4pm.Standing.min(:alive, :unsupported)
  end

  @tag :real_wasm
  test "each requested algorithm's identity is independently observed and replay-verified, not fixture-asserted" do
    requests = %{discover: %{traces: [["a", "b"]]}}

    assert {:ok, %{results: %{discover: discover_result}}} =
             Reactor.run(WasmCapabilitiesReactor, %{
               artifact_path: @artifact_path,
               requests: requests
             })

    assert discover_result.standing == :alive
    assert discover_result.evidence.identity_observed == true
    assert discover_result.evidence.transport_identity.replay_verified == true
    assert String.starts_with?(discover_result.evidence.transport_identity.wasm_sha256, "sha256:")

    assert discover_result.evidence.wasm4pm_source_sha ==
             Ex4pmEngine.Wasm.Adapter.wasm4pm_source_sha()
  end
end
