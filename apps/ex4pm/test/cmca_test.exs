defmodule Ex4pm.CmcaTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.CmcaWasm

  @problem %{
    states: Enum.map(0..7, &%{id: &1, factors_q16: List.duplicate(65_536, 10)}),
    lenses: [
      %{id: 0, q_q16: 131_072},
      %{id: 1, q_q16: 65_536},
      %{id: 2, q_q16: 0},
      %{id: 3, q_q16: -65_536}
    ],
    measure: 0,
    lens_index: 1,
    parent: List.duplicate(-1, 8),
    weights_q16: List.duplicate(List.duplicate(65_536, 8), 8)
  }

  test "cmca is receipted analytical CONSTRUCT and does not cross BRCE" do
    response = %{
      "standing" => "ALIVE",
      "result" => %{"shares_q16" => [8192, 8192, 8192, 8192, 8192, 8192, 8192, 8192]},
      "receipt" => %{
        "schema" => CmcaWasm.protocol(),
        "bcinr_source_sha" => CmcaWasm.bcinr_source_sha(),
        "bcinr_package" => "bcinr-cmca",
        "bcinr_version" => "26.7.28",
        "kernel" => CmcaWasm.kernel(),
        "authority" => "CONSTRUCT_ONLY",
        "actuation_performed" => false,
        "request_blake3" => "request-hash",
        "result_blake3" => "result-hash",
        "receipt_blake3" => "receipt-hash"
      }
    }

    identity = %{
      observed: true,
      wasm4pm_source_sha: CmcaWasm.wasm4pm_source_sha(),
      wasm_sha256: "sha256:observed-wasm",
      cmca_replay_verified: true
    }

    transport = fn _request, _opts -> {:ok, response, identity} end

    assert {:ok, run} = Ex4pm.cmca(@problem, cmca_wasm_fun: transport)
    assert run.operation == :cmca
    assert run.standing == :alive
    assert run.engine_result.engine == :cmca_wasm
    assert run.engine_result.evidence.authority == :construct_only
    assert run.engine_result.evidence.actuation_performed == false
    assert {:ok, %{replay: :chain_match}} = Ex4pm.replay(run.receipt.hash)
  end
end
