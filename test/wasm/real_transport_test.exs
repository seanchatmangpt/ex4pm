defmodule Ex4pmEngine.Wasm.RealTransportTest do
  @moduledoc """
  Real, no-mock proof that `Ex4pmEngine.Wasm.RealTransport` actually drives
  the compiled `wasm4pm-ex4pm-bindings` WASM artifact through a real
  `Wasmex` instance -- alloc, write, call, read, free, all against real
  linear memory -- rather than a fixture closure.

  Named, honest skip (not a silent pass) when the real artifact hasn't been
  built on this machine, per this repo's own Chicago-testing discipline:
  real collaborators, or a clearly-stated reason why not.
  """
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Wasm.RealTransport

  @artifact_path Path.expand(
                   "~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm"
                 )

  setup do
    if File.regular?(@artifact_path) do
      {:ok, instance} = RealTransport.start(@artifact_path)
      {:ok, instance: instance}
    else
      :skip
    end
  end

  @tag :real_wasm
  test "discover_v1 runs for real against real linear memory and returns the real directly-follows graph",
       %{instance: instance} do
    request = %{"traces" => [["a", "b", "c"], ["a", "b"]]}

    assert {:ok, response} = RealTransport.call(instance, "wasm4pm_ex4pm_discover_v1", request)

    assert %{"result" => %{"activities" => activities, "edges" => edges}, "digest" => digest} =
             response

    assert is_binary(digest)
    assert Enum.sort(activities) == ["a", "b", "c"]

    ab = Enum.find(edges, &(&1["from"] == "a" and &1["to"] == "b"))
    bc = Enum.find(edges, &(&1["from"] == "b" and &1["to"] == "c"))
    assert ab["freq"] == 2
    assert bc["freq"] == 1
  end

  @tag :real_wasm
  test "conform_v1 runs for real and returns the real directly-follows fitness", %{
    instance: instance
  } do
    request = %{
      "traces" => [["a", "b"], ["a", "c"]],
      "model_edges" => [%{"from" => "a", "to" => "b"}]
    }

    assert {:ok, response} = RealTransport.call(instance, "wasm4pm_ex4pm_conform_v1", request)
    assert %{"result" => %{"fit_traces" => 1, "total_traces" => 2}} = response
  end

  @tag :real_wasm
  test "discover_replay_v1 real-replays and agrees with the real direct recompute", %{
    instance: instance
  } do
    request = %{"traces" => [["a", "b", "c"]]}

    assert {:ok, true} =
             RealTransport.replay(instance, "wasm4pm_ex4pm_discover_replay_v1", request)
  end

  @tag :real_wasm
  test "default_transport/2 produces the {:ok, response, identity} shape Ex4pmEngine.Wasm.Adapter expects, with a real replay_verified",
       %{instance: instance} do
    transport =
      RealTransport.default_transport(instance, %{
        export_name: "wasm4pm_ex4pm_discover_v1",
        replay_export_name: "wasm4pm_ex4pm_discover_replay_v1",
        algorithm_id: :discover,
        protocol: Ex4pmEngine.Wasm.Adapter.protocol(),
        wasm4pm_source_sha: Ex4pmEngine.Wasm.Adapter.wasm4pm_source_sha()
      })

    assert {:ok, response, identity} = transport.(%{"traces" => [["a", "b"]]}, [])
    assert %{"standing" => "ALIVE", "result" => %{"activities" => _, "edges" => _}} = response

    assert %{
             "schema" => _,
             "algorithm_id" => "discover",
             "wasm_export" => "wasm4pm_ex4pm_discover_v1"
           } =
             response["receipt"]

    assert identity.observed == true
    assert identity.replay_verified == true
    assert String.starts_with?(identity.wasm_sha256, "sha256:")
  end

  @tag :real_wasm
  test "the real transport drives Ex4pmEngine.Wasm.Discover.execute/3 to a genuine :alive standing end-to-end",
       %{instance: instance} do
    transport =
      RealTransport.default_transport(instance, %{
        export_name: "wasm4pm_ex4pm_discover_v1",
        replay_export_name: "wasm4pm_ex4pm_discover_replay_v1",
        algorithm_id: :discover,
        protocol: Ex4pmEngine.Wasm.Adapter.protocol(),
        wasm4pm_source_sha: Ex4pmEngine.Wasm.Adapter.wasm4pm_source_sha()
      })

    assert {:ok, result} =
             Ex4pmEngine.Wasm.Discover.execute(:discover, %{traces: [["a", "b", "c"]]},
               discover_wasm_fun: transport
             )

    assert result.standing == :alive
    assert result.value["activities"] == ["a", "b", "c"]
  end
end
