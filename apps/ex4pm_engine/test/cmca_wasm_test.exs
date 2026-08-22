defmodule Ex4pm.Engine.CmcaWasmTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Engine.CmcaWasm
  alias Ex4pm.Refusal

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

  defp response do
    %{
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
  end

  defp exact_identity do
    %{
      observed: true,
      wasm4pm_source_sha: CmcaWasm.wasm4pm_source_sha(),
      wasm_sha256: "sha256:observed-wasm",
      cmca_replay_verified: true
    }
  end

  test "exact observed wasm execution plus replay reaches ALIVE without DO" do
    transport = fn _request, _opts -> {:ok, response(), exact_identity()} end

    assert {:ok, result} = CmcaWasm.execute(:cmca, @problem, cmca_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :cmca_wasm
    assert result.evidence.cmca_replay_verified == true
    assert result.evidence.authority == :construct_only
    assert result.evidence.actuation_performed == false
  end

  test "valid computation without observed artifact identity remains PARTIAL_ALIVE" do
    transport = fn _request, _opts -> {:ok, response()} end

    assert {:ok, result} = CmcaWasm.execute(:cmca, @problem, cmca_wasm_fun: transport)
    assert result.standing == :partial_alive
    assert result.evidence.identity_observed == false
  end

  test "wrong wasm4pm source is a typed refusal" do
    identity = %{exact_identity() | wasm4pm_source_sha: String.duplicate("0", 40)}
    transport = fn _request, _opts -> {:ok, response(), identity} end

    assert {:error, %Refusal{code: :cmca_wasm_identity_mismatch}} =
             CmcaWasm.execute(:cmca, @problem, cmca_wasm_fun: transport)
  end

  test "observed receipt without successful wasm replay is refused" do
    identity = %{exact_identity() | cmca_replay_verified: false}
    transport = fn _request, _opts -> {:ok, response(), identity} end

    assert {:error, %Refusal{code: :cmca_wasm_replay_unverified}} =
             CmcaWasm.execute(:cmca, @problem, cmca_wasm_fun: transport)
  end

  test "wrong BCINR source is refused before standing can advance" do
    response = put_in(response(), ["receipt", "bcinr_source_sha"], String.duplicate("f", 40))
    transport = fn _request, _opts -> {:ok, response, exact_identity()} end

    assert {:error, %Refusal{code: :cmca_source_identity_mismatch}} =
             CmcaWasm.execute(:cmca, @problem, cmca_wasm_fun: transport)
  end
end
