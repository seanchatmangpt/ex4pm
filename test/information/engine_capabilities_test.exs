defmodule Ex4pm.Information.EngineCapabilitiesTest do
  @moduledoc "Information-plane engine capabilities against the real bundled wasm/ferroplan."
  use ExUnit.Case, async: false

  alias Ex4pm.Information

  defp request(capability, input, options \\ %{}) do
    %{
      "protocol" => "ex4pm.information/1",
      "capability" => capability,
      "input" => input,
      "options" => options
    }
  end

  test "engine.wasm.run returns a receipted, executed result" do
    assert {:ok, response} =
             Information.execute(
               request("engine.wasm.run", %{
                 "algorithm" => "mean",
                 "request" => %{"data" => [1.0, 2.0, 3.0, 4.0]}
               })
             )

    assert response.status == :ok
    assert response.standing == :alive
    assert response.result["mean"] == 2.5
    assert response.receipts.information
    assert response.provenance.actuation_performed == false
    assert response.provenance.engine == :wasm_mean
  end

  test "engine.ferroplan.run plans through the admitted ferroplan artifact" do
    domain = "(define (domain m) (:requirements :strips) (:predicates (at ?x) (link ?x ?y))
      (:action go :parameters (?f ?t) :precondition (and (at ?f) (link ?f ?t))
       :effect (and (at ?t) (not (at ?f)))))"
    problem = "(define (problem p) (:domain m) (:objects a b c)
      (:init (at a) (link a b) (link b c)) (:goal (at c)))"

    assert {:ok, response} =
             Information.execute(
               request("engine.ferroplan.run", %{
                 "operation" => "plan",
                 "domain" => domain,
                 "problem" => problem
               })
             )

    assert response.status == :ok
    assert to_string(response.result["solved"]) == "true"
    assert response.receipts.information
    assert response.provenance.engine == :ferroplan
  end

  test "engine.standing observes real executions on both engines" do
    assert {:ok, response} = Information.execute(request("engine.standing", %{}))
    assert response.status == :ok
    assert response.standing == :alive
    assert response.result.engines.wasm4pm.executed
    assert response.result.engines.ferroplan.executed
    assert response.result.registered_wasm_algorithms == 33
  end

  test "unknown engine/algorithm/operation are typed :unknown_engine refusals" do
    for {cap, input, opts} <- [
          {"engine.wasm.run", %{"algorithm" => "rm_rf", "request" => %{}}, %{}},
          {"engine.ferroplan.run", %{"operation" => "System.cmd"}, %{}},
          {"process.discover", %{"subject" => %{}}, %{"engine" => "bogus"}}
        ] do
      assert {:ok, response} = Information.execute(request(cap, input, opts))
      assert response.status == :refused, "#{cap}: #{inspect(response.status)}"
      assert response.refusal.code == :unknown_engine
    end
  end

  test "the engine whitelist admits ferroplan and wasm_* ids" do
    for engine <- ["ferroplan", "wasm_ewma"] do
      assert {:ok, response} =
               Information.execute(
                 request("process.discover", %{"subject" => %{}}, %{"engine" => engine})
               )

      refute match?(%{refusal: %{code: :unknown_engine}}, response)
    end
  end

  test "WasmCapabilitiesReactor persists a receipt hash per algorithm in its result map" do
    {:ok, out} =
      Reactor.run(Ex4pmEngine.Reactors.WasmCapabilitiesReactor, %{
        artifact_path: Ex4pm.Test.WasmArtifact.path(),
        requests: Ex4pm.Test.WasmArtifact.canonical_requests()
      })

    assert map_size(out.results) == 33
    assert map_size(out.receipts) == 33
    assert Enum.all?(out.receipts, fn {_algo, hash} -> is_binary(hash) end)
    assert out.results.mean.receipt_hash == out.receipts.mean
  end
end
