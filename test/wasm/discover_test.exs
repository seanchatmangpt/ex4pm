defmodule Ex4pmEngine.Wasm.DiscoverTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Wasm.Discover
  alias Ex4pm.Refusal

  @subject %{traces: [["a", "b", "c"], ["a", "b"]]}

  defp response do
    %{
      "standing" => "ALIVE",
      "result" => %{
        "activities" => ["a", "b", "c"],
        "edges" => [
          %{"from" => "a", "to" => "b", "freq" => 2},
          %{"from" => "b", "to" => "c", "freq" => 1}
        ]
      },
      "receipt" => %{
        "schema" => Discover.protocol(),
        "algorithm_id" => "discover",
        "wasm_export" => Discover.wasm_export(),
        "wasm4pm_source_sha" => Discover.wasm4pm_source_sha(),
        "request_digest" => "request-digest",
        "result_digest" => "result-digest"
      }
    }
  end

  defp exact_identity do
    %{
      observed: true,
      wasm4pm_source_sha: Discover.wasm4pm_source_sha(),
      wasm_sha256: "sha256:observed-wasm",
      replay_verified: true
    }
  end

  test "id/supports?/available? reflect the discover engine contract" do
    assert Discover.id() == :wasm_discover
    assert Discover.supports?(:discover, [])
    refute Discover.supports?(:conform, [])
    refute Discover.available?([])
    assert Discover.available?(discover_wasm_fun: fn _r, _o -> :noop end)
  end

  test "exact observed wasm execution plus replay reaches ALIVE" do
    transport = fn _request, _opts -> {:ok, response(), exact_identity()} end

    assert {:ok, result} = Discover.execute(:discover, @subject, discover_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_discover
    assert result.evidence.replay_verified == true
    assert result.evidence.actuation_performed == false
  end

  test "valid computation without observed artifact identity remains PARTIAL_ALIVE" do
    transport = fn _request, _opts -> {:ok, response()} end

    assert {:ok, result} = Discover.execute(:discover, @subject, discover_wasm_fun: transport)
    assert result.standing == :partial_alive
    assert result.evidence.identity_observed == false
  end

  test "wrong observed wasm4pm source is a typed refusal" do
    identity = %{exact_identity() | wasm4pm_source_sha: String.duplicate("0", 40)}
    transport = fn _request, _opts -> {:ok, response(), identity} end

    assert {:error, %Refusal{code: :discover_wasm_identity_mismatch}} =
             Discover.execute(:discover, @subject, discover_wasm_fun: transport)
  end

  test "observed identity without successful replay is refused" do
    identity = %{exact_identity() | replay_verified: false}
    transport = fn _request, _opts -> {:ok, response(), identity} end

    assert {:error, %Refusal{code: :discover_wasm_replay_unverified}} =
             Discover.execute(:discover, @subject, discover_wasm_fun: transport)
  end

  test "wrong receipt-bound wasm4pm source is refused before standing can advance" do
    response = put_in(response(), ["receipt", "wasm4pm_source_sha"], String.duplicate("f", 40))
    transport = fn _request, _opts -> {:ok, response, exact_identity()} end

    assert {:error, %Refusal{code: :discover_source_identity_mismatch}} =
             Discover.execute(:discover, @subject, discover_wasm_fun: transport)
  end

  test "no transport callback is a typed unavailable refusal" do
    assert {:error, %Refusal{code: :discover_wasm_unavailable}} =
             Discover.execute(:discover, @subject, [])
  end
end
