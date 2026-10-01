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

  # reads PDDL examples from a local ferroplan checkout (@examples); not in CI
  @tag :live_external
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

  describe "non-object responses" do
    @fixtures Path.expand("../support/fixtures/ferroplan", __DIR__)

    setup %{pid: pid} do
      domain = File.read!(Path.join(@fixtures, "logistics_domain.pddl"))
      problem = File.read!(Path.join(@fixtures, "logistics_p1.pddl"))

      assert {:ok, %{"handle" => handle}} =
               T.call(pid, "session_new", %{"domain" => domain, "problem" => problem})

      %{handle: handle}
    end

    test "session_suffix, observe, elapse and step return {:ok, %{\"value\" => json}}",
         %{pid: pid, handle: h} do
      assert {:ok, %{"solved" => true}} =
               T.call(pid, "session_think", %{"handle" => h, "evals" => 200_000, "mem_mb" => 64})

      assert {:ok, %{"value" => [_ | _]}} = T.call(pid, "session_suffix", %{"handle" => h})

      assert {:ok, %{"value" => v}} =
               T.call(pid, "session_observe", %{
                 "handle" => h,
                 "sight" => [["(at-veh t1 a)", false], ["(at-veh t1 b)", true]]
               })

      assert is_list(v)

      assert {:ok, %{"value" => e}} = T.call(pid, "session_elapse", %{"handle" => h, "dt" => 1.0})
      assert is_list(e) or is_nil(e)

      # step is an object while a plan step exists (passes through unwrapped)
      assert {:ok, %{"action" => _}} = T.call(pid, "session_step", %{"handle" => h})
    end

    test "session_step with no plan is null, wrapped as value nil", %{pid: pid, handle: h} do
      assert {:ok, %{"value" => nil}} = T.call(pid, "session_step", %{"handle" => h})
    end
  end

  describe "decode_response/1 (pure)" do
    test "object passes through" do
      assert {:ok, %{"a" => 1}} = T.decode_response(~s({"a":1}))
    end

    test "array, null and scalars are wrapped as value" do
      assert {:ok, %{"value" => [1, 2]}} = T.decode_response("[1,2]")
      assert {:ok, %{"value" => nil}} = T.decode_response("null")
      assert {:ok, %{"value" => 3}} = T.decode_response("3")
      assert {:ok, %{"value" => "s"}} = T.decode_response(~s("s"))
    end

    test "sole-key error object is a typed engine refusal" do
      assert {:error, %Refusal{code: :ferroplan_engine_error, details: d}} =
               T.decode_response(~s({"error":{"code":"x","message":"m","retryable":true}}))

      assert d == %{code: "x", message: "m", retryable: true}
    end

    test "error key alongside others is an ordinary object" do
      assert {:ok, %{"error" => _, "b" => 1}} = T.decode_response(~s({"error":"e","b":1}))
    end

    test "unparseable bytes are ferroplan_bad_response" do
      assert {:error, %Refusal{code: :ferroplan_bad_response}} = T.decode_response("{not json")
      assert {:error, %Refusal{code: :ferroplan_bad_response}} = T.decode_response("")
    end
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

  # reads PDDL examples from a local ferroplan checkout (@examples); not in CI
  @tag :live_external
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
