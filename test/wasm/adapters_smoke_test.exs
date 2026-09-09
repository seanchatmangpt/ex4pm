defmodule Ex4pmEngine.Wasm.AdaptersSmokeTest do
  @moduledoc """
  Contract-shape coverage for the remaining Phase-1 wasm4pm-ex4pm-bindings
  adapters (conform, simulate, optimize, powl_mine). `Ex4pmEngine.Wasm.DiscoverTest`
  carries the full standing-transition matrix (ALIVE / PARTIAL_ALIVE / typed
  refusal) once for the shared `Ex4pmEngine.Wasm.Adapter` macro; these tests
  confirm each concrete module wires its own algorithm_id/engine_id/export
  names correctly rather than re-deriving the same matrix four more times.
  """

  use ExUnit.Case, async: true

  alias Ex4pmEngine.Wasm.{Conform, Optimize, PowlMine, Simulate}

  defp response_for(module, algorithm_id, result) do
    %{
      "standing" => "ALIVE",
      "result" => result,
      "receipt" => %{
        "schema" => module.protocol(),
        "algorithm_id" => to_string(algorithm_id),
        "wasm_export" => module.wasm_export(),
        "wasm4pm_source_sha" => module.wasm4pm_source_sha(),
        "request_digest" => "request-digest",
        "result_digest" => "result-digest"
      }
    }
  end

  defp exact_identity(module) do
    %{
      observed: true,
      wasm4pm_source_sha: module.wasm4pm_source_sha(),
      wasm_sha256: "sha256:observed-wasm",
      replay_verified: true
    }
  end

  test "conform: id/supports?/alive path" do
    assert Conform.id() == :wasm_conform
    assert Conform.supports?(:conform, [])

    subject = %{traces: [["a", "b"]], model_edges: [%{from: "a", to: "b"}]}
    result_body = %{"fitness" => 1.0, "fit_traces" => 1, "total_traces" => 1}

    transport = fn _r, _o ->
      {:ok, response_for(Conform, :conform, result_body), exact_identity(Conform)}
    end

    assert {:ok, result} = Conform.execute(:conform, subject, conform_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_conform
  end

  test "simulate: id/supports?/alive path" do
    assert Simulate.id() == :wasm_simulate
    assert Simulate.supports?(:simulate, [])

    subject = %{edges: [%{from: "a", to: "b"}], start: "a", steps: 1, seed: 42}
    result_body = %{"trace" => ["a", "b"]}

    transport = fn _r, _o ->
      {:ok, response_for(Simulate, :simulate, result_body), exact_identity(Simulate)}
    end

    assert {:ok, result} = Simulate.execute(:simulate, subject, simulate_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_simulate
  end

  test "optimize: id/supports?/alive path" do
    assert Optimize.id() == :wasm_optimize
    assert Optimize.supports?(:optimize, [])

    subject = %{edges: [%{from: "a", to: "b", duration: 1.0}], start: "a", end: "b"}
    result_body = %{"path" => ["a", "b"], "duration" => 1.0}

    transport = fn _r, _o ->
      {:ok, response_for(Optimize, :optimize, result_body), exact_identity(Optimize)}
    end

    assert {:ok, result} = Optimize.execute(:optimize, subject, optimize_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_optimize
  end

  test "powl_mine: id/supports?/alive path" do
    assert PowlMine.id() == :wasm_powl_mine
    assert PowlMine.supports?(:powl_mine, [])

    subject = %{traces: [["a", "b"], ["a", "b"]]}
    result_body = %{"node_type" => "sequence", "children" => ["a", "b"]}

    transport = fn _r, _o ->
      {:ok, response_for(PowlMine, :powl_mine, result_body), exact_identity(PowlMine)}
    end

    assert {:ok, result} = PowlMine.execute(:powl_mine, subject, powl_mine_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_powl_mine
  end
end
