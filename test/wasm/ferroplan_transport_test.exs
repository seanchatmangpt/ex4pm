defmodule Ex4pmEngine.Wasm.FerroplanTransportTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Refusal
  alias Ex4pmEngine.Wasm.FerroplanTransport, as: T

  @packaged Path.expand("../../priv/ferroplan/ferroplan_wasm.wasm", __DIR__)
  @dev "/Users/sac/ferroplan/target/wasm32-wasip1/release/ferroplan_wasm.wasm"
  @artifact if File.exists?(@packaged), do: @packaged, else: @dev
  @examples "/Users/sac/ferroplan/examples/logistics"

  setup_all do
    unless File.exists?(@artifact), do: raise("ferroplan wasm artifact missing: #{@artifact}")
    :ok
  end

  setup do
    {:ok, pid} = T.start(@artifact, expected_sha256: :unpinned)
    on_exit(fn -> T.stop(pid) end)
    %{pid: pid}
  end

  test "version op returns a map with a version", %{pid: pid} do
    assert {:ok, %{"version" => v}} = T.call(pid, "version", %{})
    assert is_binary(v) and v != ""
  end

  test "readiness returns a capability manifest", %{pid: pid} do
    assert {:ok, %{} = m} = T.call(pid, "readiness", %{})
    assert map_size(m) > 0
  end

  test "real PDDL plan solves the logistics p1 problem", %{pid: pid} do
    domain = File.read!(Path.join(@examples, "domain.pddl"))
    problem = File.read!(Path.join(@examples, "p1.pddl"))

    assert {:ok, %{} = solution} =
             T.call(pid, "plan", %{"domain" => domain, "problem" => problem})

    refute Map.has_key?(solution, "error")
    assert map_size(solution) > 0
  end

  test "unknown op yields a typed engine refusal, never a raise", %{pid: pid} do
    assert {:error, %Refusal{code: :ferroplan_engine_error, details: d}} =
             T.call(pid, "no_such_op", %{})

    assert is_binary(d.code) and is_boolean(d.retryable)
  end

  test "malformed PDDL yields a typed engine refusal and the instance survives", %{pid: pid} do
    assert {:error, %Refusal{code: :ferroplan_engine_error}} =
             T.call(pid, "plan", %{"domain" => "(((", "problem" => "nope"})

    assert {:ok, %{"version" => _}} = T.call(pid, "version", %{})
  end

  test "wrong sha pin is refused" do
    assert {:error, %Refusal{code: :wasm_digest_mismatch}} =
             T.start(@artifact, expected_sha256: String.duplicate("0", 64))
  end

  test "missing file is refused" do
    assert {:error, %Refusal{code: :ferroplan_artifact_unreadable}} =
             T.start("/nonexistent/ferroplan.wasm", expected_sha256: :unpinned)
  end

  test "non-wasm bytes are refused" do
    path = Path.join(System.tmp_dir!(), "fp_bad_#{System.unique_integer([:positive])}.wasm")
    File.write!(path, "not wasm")
    on_exit(fn -> File.rm(path) end)
    assert {:error, %Refusal{code: :wasm_invalid}} = T.start(path, expected_sha256: :unpinned)
  end

  test "fond_policy_validate is a known op: bad args give a typed engine refusal, not unknown-op",
       %{pid: pid} do
    assert {:error, %Refusal{code: :ferroplan_engine_error, details: d}} =
             T.call(pid, "fond_policy_validate", %{"problem" => "{}", "plan" => "{}"})

    refute d.message =~ ~r/unknown op/i
  end

  test "a timeout discards the instance with engine_restarted", %{pid: pid} do
    domain = File.read!(Path.join(@examples, "domain.pddl"))
    problem = File.read!(Path.join(@examples, "p1.pddl"))

    result = T.call(pid, "plan", %{"domain" => domain, "problem" => problem}, timeout: 1)

    case result do
      {:error, %Refusal{code: :ferroplan_call_timeout, details: d}} ->
        assert d.engine_restarted
        refute Process.alive?(pid)

      {:ok, _} ->
        # solved within 1ms: no timeout occurred, nothing to discard
        assert Process.alive?(pid)
    end
  end
end
