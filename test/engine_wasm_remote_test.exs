defmodule Ex4pm.EngineWasmRemoteTest do
  @moduledoc """
  Chicago-style tests for Ex4pm.Engine.WasmRemote (Phase 1,
  docs/EX4PM-THINNING-BEAM4PM-ENRICHMENT.md §6). No mocking library: the
  injected `:wasm_remote_fun` callback is a real, plain 2-arity function,
  the same pattern `test/engine_test.exs`'s existing `:remote_fun`
  (`Ex4pm.Engine.Remote`) coverage already uses.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.Engine

  describe "successful execution with a full identity envelope" do
    test "real callback returning a verified identity yields ALIVE standing" do
      real_fun = fn :simulate, subject ->
        {:ok, %{echo: subject},
         %{
           observed: true,
           transport: :https,
           source_sha: "abc123def456",
           image_digest: "sha256:realdigest",
           receipt_verified: true
         }}
      end

      assert {:ok, result} =
               Engine.execute(:simulate, %{probe: true},
                 engine: :wasm_remote,
                 wasm_remote_fun: real_fun
               )

      assert result.engine == :wasm_remote
      assert result.operation == :simulate
      assert result.value == %{echo: %{probe: true}}
      assert result.standing == :alive
      assert result.evidence.executed == true
      assert result.evidence.transport == :https
      assert result.evidence.exact_artifact == true
    end
  end

  describe "unavailable without a configured callback" do
    test "no :wasm_remote_fun opt yields wasm_remote_unavailable refusal" do
      assert {:error, refusal} = Engine.execute(:simulate, %{probe: true}, engine: :wasm_remote)

      assert refusal.code == :wasm_remote_unavailable
    end

    test "candidates/2 reports :wasm_remote as :unsupported when unconfigured" do
      candidates = Engine.candidates(:simulate, [])
      wasm_remote = Enum.find(candidates, &(&1.id == :wasm_remote))

      refute is_nil(wasm_remote)
      assert wasm_remote.standing == :unsupported
    end
  end

  describe "wasm_remote_timeout refusal" do
    test "callback returning {:error, :timeout} yields a distinct timeout refusal" do
      timeout_fun = fn :simulate, _subject -> {:error, :timeout} end

      assert {:error, refusal} =
               Engine.execute(:simulate, %{probe: true},
                 engine: :wasm_remote,
                 wasm_remote_fun: timeout_fun
               )

      assert refusal.code == :wasm_remote_timeout
      assert refusal.code != :wasm_remote_unavailable
    end

    test "callback raising a real timeout-shaped exit is caught as wasm_remote_timeout" do
      raising_fun = fn :simulate, _subject ->
        exit({:timeout, {GenServer, :call, [:some_server, :ping, 5_000]}})
      end

      assert {:error, refusal} =
               Engine.execute(:simulate, %{probe: true},
                 engine: :wasm_remote,
                 wasm_remote_fun: raising_fun
               )

      assert refusal.code == :wasm_remote_timeout
    end
  end

  describe "identity mismatch / partial_alive admission" do
    test "callback returning a value with no identity is PARTIAL_ALIVE and unproven" do
      no_identity_fun = fn :simulate, subject -> {:ok, %{echo: subject}} end

      assert {:ok, result} =
               Engine.execute(:simulate, %{probe: true},
                 engine: :wasm_remote,
                 wasm_remote_fun: no_identity_fun
               )

      assert result.standing == :partial_alive
      assert result.evidence.remote_identity == :unproven
      assert result.evidence.exact_artifact == false
    end

    test "identity missing receipt_verified stays PARTIAL_ALIVE, not ALIVE" do
      partial_fun = fn :simulate, subject ->
        {:ok, %{echo: subject},
         %{
           observed: true,
           transport: :https,
           source_sha: "abc123",
           image_digest: "sha256:digest",
           receipt_verified: false
         }}
      end

      assert {:ok, result} =
               Engine.execute(:simulate, %{probe: true},
                 engine: :wasm_remote,
                 wasm_remote_fun: partial_fun
               )

      assert result.standing == :partial_alive
      assert result.evidence.exact_artifact == false
    end

    test "observed image_digest not matching the admitted digest is refused" do
      mismatched_fun = fn :simulate, subject ->
        {:ok, %{echo: subject},
         %{
           observed: true,
           transport: :https,
           source_sha: "abc123",
           image_digest: "sha256:wrong-digest",
           receipt_verified: true
         }}
      end

      assert {:error, refusal} =
               Engine.execute(:simulate, %{probe: true},
                 engine: :wasm_remote,
                 wasm_remote_fun: mismatched_fun,
                 wasm_remote_image_digest: "sha256:expected-digest"
               )

      assert refusal.code == :wasm_remote_identity_mismatch
      assert refusal.details.expected == "sha256:expected-digest"
      assert refusal.details.observed == "sha256:wrong-digest"
    end
  end
end
