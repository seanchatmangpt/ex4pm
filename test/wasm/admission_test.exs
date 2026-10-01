defmodule Ex4pmEngine.Wasm.AdmissionTest do
  @moduledoc """
  Chicago-style court for `Ex4pmEngine.Wasm.Admission` and the hardened
  `Ex4pmEngine.Wasm.RealTransport` call path. No mocks: every case runs real
  Wasmtime via Wasmex.

  Two subjects:

    * a tiny REAL wasm fixture (assembled from WAT with `wasm-opt`, embedded
      below as base64; source in `@fixture_wat`) implementing the ex4pm ABI
      (alloc/free/dealloc, `discover`, `<algo>_replay_v1`) plus deliberately
      misbehaving exports -- always runs;
    * the real `wasm4pm_ex4pm_bindings.wasm` artifact (resolved by
      `Ex4pm.Test.WasmArtifact.path/0`) -- skipped when absent unless
      `EX4PM_WASM_REQUIRED=1`, which turns absence into a failure.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.Refusal
  alias Ex4pmEngine.Wasm.{Admission, RealTransport}

  @artifact_path Ex4pm.Test.WasmArtifact.path()
  # nil when the artifact exists; a skip reason when absent; raises (=> failure)
  # under EX4PM_WASM_REQUIRED=1.
  @artifact_skip_reason Ex4pm.Test.WasmArtifact.skip_reason()

  # (module (import "env" "host_fn" (func (param i32) (result i32))) ...) -- exports:
  # memory, alloc/free/dealloc_v1, discover_v1 (+replay), badreplay/badutf8/badjson/
  # array/huge/trap _v1 fixtures. data segments: 16 JSON object(35B), 64 ff fe, 80 "not json", 96 "[1]".
  @fixture_b64 Enum.join([
                 "AGFzbQEAAAABGARgA39/fwF/YAF/AX9gAn9/AGACf38BfwIPAQNlbnYHaG9zdF9mbgABAwwLAQIC",
                 "AAMDAAAAAAAFAwEAAgYHAX8BQYAICwfMAgwGbWVtb3J5AgAfd2FzbTRwbV9leDRwbV9iaW5kaW5n",
                 "c19hbGxvY192MQABHndhc200cG1fZXg0cG1fYmluZGluZ3NfZnJlZV92MQACIXdhc200cG1fZXg0",
                 "cG1fYmluZGluZ3NfZGVhbGxvY192MQADGXdhc200cG1fZXg0cG1fZGlzY292ZXJfdjEABCB3YXNt",
                 "NHBtX2V4NHBtX2Rpc2NvdmVyX3JlcGxheV92MQAFGndhc200cG1fZXg0cG1fYmFkcmVwbGF5X3Yx",
                 "AAYYd2FzbTRwbV9leDRwbV9iYWR1dGY4X3YxAAcYd2FzbTRwbV9leDRwbV9iYWRqc29uX3YxAAgW",
                 "d2FzbTRwbV9leDRwbV9hcnJheV92MQAJFXdhc200cG1fZXg0cG1faHVnZV92MQAKFXdhc200cG1f",
                 "ZXg0cG1fdHJhcF92MQALDAEECmwLEQEBfyMAIQEjACAAaiQAIAELAwABCwMAAQsLACACQSM2AgBB",
                 "EAsEAEEBCwQAQQcLDAAgAkECNgIAQcAACwwAIAJBCDYCAEHQAAsMACACQQM2AgBB4AALDwAgAkH/",
                 "////BzYCAEEQCwMAAAsLSAQAQRALI3siZGlnZXN0IjoiZCIsInJlc3VsdCI6eyJvayI6dHJ1ZX19",
                 "AEHAAAsC//4AQdAACwhub3QganNvbgBB4AALA1sxXQ=="
               ])
  @fixture_bytes Base.decode64!(@fixture_b64)
  @fixture_allow [{"env", "host_fn", [:i32], [:i32]}]
  @fixture_required [
    "memory",
    "wasm4pm_ex4pm_bindings_alloc_v1",
    "wasm4pm_ex4pm_bindings_free_v1",
    "wasm4pm_ex4pm_bindings_dealloc_v1",
    "wasm4pm_ex4pm_discover_v1",
    "wasm4pm_ex4pm_discover_replay_v1"
  ]

  defp fixture_opts(extra \\ []) do
    Keyword.merge(
      [
        expected_sha256: sha_hex(@fixture_bytes),
        import_allowlist: @fixture_allow,
        required_exports: @fixture_required
      ],
      extra
    )
  end

  defp sha_hex(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp scratch_file(name, bytes) do
    dir = Path.join(System.tmp_dir!(), "ex4pm_admission_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, name)
    File.write!(path, bytes)
    on_exit(fn -> File.rm_rf(dir) end)
    path
  end

  defp start_fixture(extra \\ []) do
    path = scratch_file("fixture.wasm", @fixture_bytes)
    {:ok, instance} = RealTransport.start(path, fixture_opts(extra))
    instance
  end

  describe "Admission against the real fixture module" do
    test "admits a pinned module and emits [:ex4pm, :wasm, :admit] telemetry" do
      id = "adm-#{System.unique_integer([:positive])}"
      test_pid = self()

      :telemetry.attach(
        id,
        [:ex4pm, :wasm, :admit],
        fn _e, m, meta, _ -> send(test_pid, {:admit, m, meta}) end,
        nil
      )

      on_exit(fn -> :telemetry.detach(id) end)

      assert {:ok, admitted} = Admission.admit(@fixture_bytes, fixture_opts())
      assert admitted.sha256 == "sha256:" <> sha_hex(@fixture_bytes)
      assert_receive {:admit, %{duration: _}, %{outcome: :admitted, wasm_sha256: _}}
    end

    test "wrong pin is :wasm_digest_mismatch carrying expected and actual" do
      wrong = String.duplicate("0", 64)

      assert {:error, %Refusal{code: :wasm_digest_mismatch, details: d}} =
               Admission.admit(@fixture_bytes, fixture_opts(expected_sha256: wrong))

      assert d.expected == wrong
      assert d.actual == sha_hex(@fixture_bytes)
    end

    test "nil or absent pin fails closed; :unpinned is the only opt-out" do
      assert {:error, %Refusal{code: :wasm_digest_unpinned}} =
               Admission.admit(@fixture_bytes, fixture_opts(expected_sha256: nil))

      assert {:error, %Refusal{code: :wasm_digest_unpinned}} =
               Admission.admit(@fixture_bytes, Keyword.delete(fixture_opts(), :expected_sha256))

      assert {:ok, _} = Admission.admit(@fixture_bytes, fixture_opts(expected_sha256: :unpinned))
    end

    test "a one-byte flip in a data segment still compiles but breaks the pin" do
      {pre, _} = :binary.match(@fixture_bytes, "not json")
      <<head::binary-size(pre), b, tail::binary>> = @fixture_bytes
      flipped = <<head::binary, Bitwise.bxor(b, 1), tail::binary>>

      assert byte_size(flipped) == byte_size(@fixture_bytes)
      assert flipped != @fixture_bytes

      assert {:error, %Refusal{code: :wasm_digest_mismatch}} =
               Admission.admit(flipped, fixture_opts())

      # control: the flipped copy is itself valid wasm under its own pin
      assert {:ok, _} = Admission.admit(flipped, fixture_opts(expected_sha256: sha_hex(flipped)))
    end

    test "import outside the allowlist is :wasm_import_surface_mismatch naming it; cache does not leak" do
      assert {:ok, _} = Admission.admit(@fixture_bytes, fixture_opts())

      assert {:error, %Refusal{code: :wasm_import_surface_mismatch, details: d}} =
               Admission.admit(@fixture_bytes, fixture_opts(import_allowlist: []))

      assert d.unexpected == ["env.host_fn"]

      # missing/empty allowlist means NO imports -- never allow-all
      assert {:error, %Refusal{code: :wasm_import_surface_mismatch}} =
               Admission.admit(
                 @fixture_bytes,
                 fixture_opts(import_allowlist: [{"other", "x", [], []}])
               )

      # still admitted with the full allowlist afterwards
      assert {:ok, _} = Admission.admit(@fixture_bytes, fixture_opts())
    end

    test "signature mismatch on an allowlisted import is refused as mismatched" do
      assert {:error, %Refusal{code: :wasm_import_surface_mismatch, details: d}} =
               Admission.admit(
                 @fixture_bytes,
                 fixture_opts(import_allowlist: [{"env", "host_fn", [:i64], [:i32]}])
               )

      assert d.mismatched == ["env.host_fn"]
    end

    test "missing required export is :wasm_missing_export" do
      assert {:error, %Refusal{code: :wasm_missing_export, details: %{missing: ["nope_v1"]}}} =
               Admission.admit(
                 @fixture_bytes,
                 fixture_opts(required_exports: ["nope_v1" | @fixture_required])
               )
    end

    test "non-wasm bytes and truncated wasm are :wasm_invalid" do
      junk = "definitely not wasm"

      assert {:error, %Refusal{code: :wasm_invalid}} =
               Admission.admit(junk, fixture_opts(expected_sha256: sha_hex(junk)))

      trunc = binary_part(@fixture_bytes, 0, 40)

      assert {:error, %Refusal{code: :wasm_invalid}} =
               Admission.admit(trunc, fixture_opts(expected_sha256: sha_hex(trunc)))
    end

    test "default allowlist comes from MANIFEST.json (zero-import artifact => empty, protocol pinned)" do
      allow = Admission.import_allowlist()
      # The pinned artifact is built with no host imports (build-wasm.sh), so the
      # allowlist is empty and admission refuses ANY import (fail closed).
      assert allow == []

      assert Enum.all?(allow, fn {m, n, p, r} ->
               is_binary(m) and is_binary(n) and is_list(p) and is_list(r)
             end)

      assert Admission.manifest()["protocol"] == "wasm4pm.ex4pm-bindings/v1"
      assert "memory" in Admission.required_exports()
    end
  end

  describe "RealTransport against the real fixture module" do
    test "start/2 with nil pin is refused :wasm_digest_unpinned" do
      path = scratch_file("fixture.wasm", @fixture_bytes)

      assert {:error, %Refusal{code: :wasm_digest_unpinned}} =
               RealTransport.start(path, fixture_opts(expected_sha256: nil))
    end

    test "start/2 refuses a wrong pin before instantiating" do
      path = scratch_file("fixture.wasm", @fixture_bytes)

      assert {:error, %Refusal{code: :wasm_digest_mismatch}} =
               RealTransport.start(path, fixture_opts(expected_sha256: String.duplicate("1", 64)))
    end

    test "call/3 and replay/3 run the real ABI end to end; stubs come from the allowlist" do
      instance = start_fixture()
      assert instance.artifact_hash == "sha256:" <> sha_hex(@fixture_bytes)

      assert {:ok, %{"digest" => "d", "result" => %{"ok" => true}}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_discover_v1", %{"traces" => []})

      assert {:ok, true} =
               RealTransport.replay(instance, "wasm4pm_ex4pm_discover_replay_v1", %{
                 "traces" => []
               })
    end

    test "replay result other than 0/1 is :malformed_response" do
      instance = start_fixture()

      assert {:error, %Refusal{code: :malformed_response}} =
               RealTransport.replay(instance, "wasm4pm_ex4pm_badreplay_v1", %{})
    end

    test "trap is :call_trapped and the instance stays usable (buffers freed)" do
      instance = start_fixture()

      assert {:error, %Refusal{code: :call_trapped}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_trap_v1", %{})

      assert {:ok, %{"digest" => "d"}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_discover_v1", %{})
    end

    test "unknown export is :call_trapped, not a crash" do
      instance = start_fixture()

      assert {:error, %Refusal{code: :call_trapped}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_nonexistent_v1", %{})
    end

    test "response shape refusals: invalid UTF-8, invalid JSON, non-object" do
      instance = start_fixture()

      assert {:error, %Refusal{code: :invalid_encoding}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_badutf8_v1", %{})

      assert {:error, %Refusal{code: :invalid_json}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_badjson_v1", %{})

      assert {:error, %Refusal{code: :malformed_response}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_array_v1", %{})
    end

    test "oversized request and oversized response are :resource_limit" do
      instance = start_fixture()

      assert {:error, %Refusal{code: :resource_limit, details: %{limit: 8}}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_discover_v1", %{"k" => "xxxxxxxxxxxx"},
                 max_request_bytes: 8
               )

      assert {:error, %Refusal{code: :resource_limit}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_huge_v1", %{})

      assert {:error, %Refusal{code: :resource_limit}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_discover_v1", %{},
                 max_response_bytes: 4
               )
    end

    test "request with invalid UTF-8 is :invalid_encoding" do
      instance = start_fixture()

      assert {:error, %Refusal{code: :invalid_encoding}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_discover_v1", %{"k" => <<0xFF, 0xFE>>})
    end

    test "a dead Wasmex instance yields a refusal, not an exit" do
      instance = start_fixture()
      :ok = GenServer.stop(instance.pid)

      assert {:error, %Refusal{code: :call_trapped}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_discover_v1", %{})

      assert {:error, %Refusal{code: :call_trapped}} =
               RealTransport.replay(instance, "wasm4pm_ex4pm_discover_replay_v1", %{})
    end
  end

  describe "Admission against the real wasm4pm artifact" do
    if @artifact_skip_reason do
      @describetag skip: @artifact_skip_reason
    end

    test "unmodified artifact admits under the manifest allowlist; wrong pin refuses" do
      bytes = File.read!(@artifact_path)

      assert {:ok, _} = Admission.admit(bytes, expected_sha256: :unpinned)

      assert {:error, %Refusal{code: :wasm_digest_mismatch}} =
               Admission.admit(bytes, expected_sha256: String.duplicate("0", 64))
    end

    test "removing one allowlist entry the artifact imports yields :wasm_import_surface_mismatch naming it" do
      bytes = File.read!(@artifact_path)
      {:ok, store} = Wasmex.Store.new()
      {:ok, module} = Wasmex.Module.compile(store, bytes)

      imported =
        for {ns, items} <- Wasmex.Module.imports(module), {name, _sig} <- items, do: {ns, name}

      case imported do
        [] ->
          # zero-import artifact: the empty allowlist must admit it
          assert {:ok, _} =
                   Admission.admit(bytes, expected_sha256: :unpinned, import_allowlist: [])

        [{ns, name} | _] ->
          rest =
            Enum.reject(Admission.import_allowlist(), fn {m, n, _, _} -> {m, n} == {ns, name} end)

          assert {:error, %Refusal{code: :wasm_import_surface_mismatch, details: d}} =
                   Admission.admit(bytes, expected_sha256: :unpinned, import_allowlist: rest)

          assert "#{ns}.#{name}" in d.unexpected
      end
    end

    test "start/2 boots the artifact and discover_v1 runs for real" do
      {:ok, instance} = RealTransport.start(@artifact_path, expected_sha256: :unpinned)

      assert {:ok, %{"result" => %{"activities" => _}}} =
               RealTransport.call(instance, "wasm4pm_ex4pm_discover_v1", %{
                 "traces" => [["a", "b"]]
               })

      assert {:ok, true} =
               RealTransport.replay(instance, "wasm4pm_ex4pm_discover_replay_v1", %{
                 "traces" => [["a", "b"]]
               })
    end
  end
end
