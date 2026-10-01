defmodule Ex4pmEngine.Wasm.HostTest do
  @moduledoc """
  Real, no-mock proof of the supervised wasm host: real artifact, real Wasmex
  instance, real kill/recovery. Artifact via EX4PM_WASM_ARTIFACT.
  """
  use ExUnit.Case, async: false

  alias Ex4pm.Refusal
  alias Ex4pmEngine.Wasm.{Discover, Host}

  @artifact System.get_env("EX4PM_WASM_ARTIFACT") ||
              Path.expand(
                "~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm"
              )

  if not File.regular?(@artifact) and System.get_env("EX4PM_WASM_REQUIRED") != "1" do
    @moduletag skip: "wasm artifact not built: #{@artifact}"
  end

  @subject %{traces: [["a", "b", "c"], ["a", "b"]]}

  setup do
    # Replace any app-supervised default Host with one under test control.
    _ = Supervisor.terminate_child(Ex4pm.Supervisor, Host)
    _ = Supervisor.delete_child(Ex4pm.Supervisor, Host)

    on_exit(fn ->
      if Process.whereis(Ex4pm.Supervisor),
        do: Supervisor.start_child(Ex4pm.Supervisor, Host)
    end)

    pin = :crypto.hash(:sha256, File.read!(@artifact)) |> Base.encode16(case: :lower)
    {:ok, pin: pin}
  end

  defp start_host(opts) do
    start_supervised!({Host, opts}, restart: :temporary)
  end

  test "boots with the real artifact and reports admitted status", %{pin: pin} do
    start_host(artifact_path: @artifact, expected_sha256: pin)
    st = Host.status()
    assert st.admitted
    assert st.alive
    assert st.refusal == nil
    assert st.sha256 == pin or st.sha256 == "sha256:" <> pin
    assert st.restarts == 0
    assert st.artifact_path == @artifact
  end

  test "discover through the fallback without a transport opt is :alive and replay-verified",
       %{pin: pin} do
    start_host(artifact_path: @artifact, expected_sha256: pin)
    assert Discover.available?([])
    assert {:ok, result} = Discover.execute(:discover, @subject, [])
    assert result.standing == :alive
    assert result.engine == :wasm_discover
    assert inspect(result) =~ "replay_verified"

    # wasm_default: false disables the fallback; explicit option still wins.
    refute Discover.available?(wasm_default: false)
    assert {:error, %Refusal{}} = Discover.execute(:discover, @subject, wasm_default: false)

    explicit = fn _r, _o -> {:error, :explicit_won} end

    assert {:error, %Refusal{}} =
             Discover.execute(:discover, @subject, discover_wasm_fun: explicit)
  end

  test "killing the wasmex instance: Host recovers and the next call succeeds", %{pin: pin} do
    start_host(artifact_path: @artifact, expected_sha256: pin)
    assert {:ok, %{standing: :alive}} = Discover.execute(:discover, @subject, [])

    {:ok, %{pid: old}} = Host.instance()
    ref = Process.monitor(old)
    Process.exit(old, :kill)
    assert_receive {:DOWN, ^ref, _, _, _}, 5_000

    assert {:ok, %{standing: :alive}} = Discover.execute(:discover, @subject, [])
    {:ok, %{pid: new}} = Host.instance()
    assert new != old
    assert Process.alive?(new)
    assert Host.status().restarts >= 1
  end

  test "wrong sha yields a typed refusal and the app stays alive" do
    start_host(artifact_path: @artifact, expected_sha256: String.duplicate("0", 64))
    st = Host.status()
    refute st.admitted
    assert %Refusal{code: :wasm_digest_mismatch} = st.refusal
    assert {:error, %Refusal{code: :wasm_digest_mismatch}} = Host.transports()
    refute Discover.available?([])
    assert Process.alive?(Process.whereis(Ex4pm.Supervisor))
  end

  test "missing path yields a typed refusal and the app stays alive" do
    start_host(artifact_path: "/private/tmp/does-not-exist.wasm")
    st = Host.status()
    refute st.admitted
    assert %Refusal{code: :wasm_artifact_missing} = st.refusal
    assert {:error, %Refusal{}} = Host.transports()
    assert Process.alive?(Process.whereis(Ex4pm.Supervisor))
  end

  test "20 concurrent calls return correct results", %{pin: pin} do
    start_host(artifact_path: @artifact, expected_sha256: pin)
    {:ok, transports} = Host.transports()
    assert Keyword.has_key?(transports, :discover_wasm_fun)

    results =
      1..20
      |> Task.async_stream(
        fn _ -> Discover.execute(:discover, @subject, transports) end,
        max_concurrency: 20,
        timeout: 60_000
      )
      |> Enum.map(fn {:ok, r} -> r end)

    assert length(results) == 20
    assert Enum.all?(results, &match?({:ok, %{standing: :alive}}, &1))
  end
end
