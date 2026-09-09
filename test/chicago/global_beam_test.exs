defmodule Ex4pm.Chicago.Cluster do
  def ensure_origin! do
    unless Node.alive?() do
      name = String.to_atom("ex4pm_chicago_#{System.unique_integer([:positive])}")
      {:ok, _pid} = :net_kernel.start(name, %{name_domain: :shortnames})
    end

    Node.set_cookie(:ex4pm_chicago_cookie)
    :ok
  end

  def start_peer! do
    options = %{
      name: :peer.random_name(:ex4pm_chicago),
      longnames: false,
      peer_down: :continue,
      args: [~c"-setcookie", Atom.to_charlist(Node.get_cookie())]
    }

    {:ok, peer, node} = :peer.start_link(options)
    :ok = bootstrap!(node)
    {peer, node}
  end

  def stop_peer({peer, _node}) do
    :peer.stop(peer)
  catch
    _, _ -> :ok
  end

  defp bootstrap!(node) do
    :ok = :erpc.call(node, :code, :add_paths, [:code.get_path()], 15_000)
    {:ok, _} = :erpc.call(node, :application, :ensure_all_started, [:ex4pm_runtime], 15_000)

    with {module, binary, filename} <- :code.get_object_code(Ex4pm.Chicago.GlobalBeamTest) do
      :erpc.call(node, :code, :load_binary, [module, filename, binary], 15_000)
    end

    :pong = Node.ping(node)
    :ok
  end
end

defmodule Ex4pm.Chicago.GlobalBeamTest do
  use ExUnit.Case, async: false

  @moduletag :chicago
  @moduletag timeout: 120_000

  alias Ex4pm.Evidence.{BRCE, DetsStore, Replay, Store}
  alias Ex4pm.POWL
  alias Ex4pm.Runtime
  alias Ex4pm.Runtime.Distributed

  setup_all do
    :ok = Ex4pm.Chicago.Cluster.ensure_origin!()
    peers = for _ <- 1..3, do: Ex4pm.Chicago.Cluster.start_peer!()

    on_exit(fn -> Enum.each(peers, &Ex4pm.Chicago.Cluster.stop_peer/1) end)

    {:ok, peers: peers, nodes: Enum.map(peers, &elem(&1, 1))}
  end

  def concurrency_probe(delay_ms) do
    started_us = System.system_time(:microsecond)
    Process.sleep(delay_ms)

    %{
      started_us: started_us,
      finished_us: System.system_time(:microsecond),
      node: Node.self()
    }
  end

  test "qualification observes exact BEAM identity and finite system limits", %{nodes: nodes} do
    observation = Ex4pm.Qualification.environment()

    assert observation.otp_release == System.otp_release()
    assert observation.erts_version == to_string(:erlang.system_info(:version))
    assert observation.schedulers_online > 0
    assert observation.process_limit > observation.process_count
    assert observation.word_size in [4, 8]
    assert observation.distribution.distribution_enabled
    assert observation.observation_hash =~ "sha256:"

    remote_versions =
      Enum.map(nodes, &:erpc.call(&1, :erlang, :system_info, [:version], 5_000))

    assert Enum.uniq(remote_versions) == [:erlang.system_info(:version)]
  end

  test "the same admitted POWL subject is semantically equivalent locally and across three peers",
       %{
         nodes: nodes
       } do
    model =
      powl!(
        for(id <- ~w(a b c d e f), do: %{id: id, intent: %{value: %{completed: id}}}),
        [{"a", "d"}, {"b", "d"}, {"c", "e"}, {"d", "f"}, {"e", "f"}]
      )

    {:ok, plan} = Runtime.compile(model)
    authority = %{id: "chicago", capabilities: [:do]}

    assert {:ok, local} = Runtime.execute(plan, authority, max_concurrency: 3)

    assert {:ok, distributed} =
             Distributed.execute(plan, authority,
               nodes: nodes,
               max_concurrency: 3,
               timeout: 10_000
             )

    assert Ex4pm.Qualification.execution_semantics(local) ==
             Ex4pm.Qualification.execution_semantics(distributed)

    assert local.runtime == :reactor
    assert distributed.runtime == :reactor_distributed
    assert length(distributed.receipt_hashes) == 6
    assert distributed.nodes == nodes
    assert MapSet.size(MapSet.new(Enum.map(distributed.placements, & &1.node))) == 3

    for layer <- distributed.layers, item <- layer do
      assert {:ok, %{replay: :match}} = Replay.verify(item.pending)
      assert {:ok, %{replay: :match}} = Replay.verify(item.receipt)
      assert {:ok, mirrored_pending} = Store.get(item.pending.hash)
      assert {:ok, mirrored_outcome} = Store.get(item.receipt.hash)
      assert mirrored_pending.hash == item.pending.hash
      assert mirrored_outcome.hash == item.receipt.hash
    end
  end

  test "high fan-out honors Reactor concurrency and closes every remote receipt", %{nodes: nodes} do
    task_count = 40

    tasks =
      for index <- 1..task_count do
        %{
          id: "fanout-#{index}",
          intent: %{
            operation: :fanout_probe,
            mfa: {Distributed, :concurrency_probe, [75]}
          }
        }
      end

    {:ok, plan} = tasks |> powl!([]) |> Runtime.compile()
    authority = %{id: "chicago", capabilities: [:do]}

    assert {:ok, execution} =
             Distributed.execute(plan, authority,
               nodes: nodes,
               max_concurrency: 4,
               timeout: 10_000
             )

    intervals = for layer <- execution.layers, item <- layer, do: item.result
    peak = max_observed_overlap(intervals)

    assert peak <= 4
    assert peak > 1
    assert length(execution.receipt_hashes) == task_count
    assert Enum.count(execution.placements) == task_count

    placement_counts = execution.placements |> Enum.frequencies_by(& &1.node) |> Map.values()
    assert Enum.max(placement_counts) - Enum.min(placement_counts) <= 1
  end

  test "an unreachable admitted node is refused before DO", %{nodes: [node | _]} do
    dead_peer = Ex4pm.Chicago.Cluster.start_peer!()
    dead_node = elem(dead_peer, 1)
    :ok = Ex4pm.Chicago.Cluster.stop_peer(dead_peer)
    wait_until(fn -> Node.ping(dead_node) == :pang end)

    {:ok, plan} = Runtime.compile(powl!([%{id: "a"}], []))

    assert {:error, %Ex4pm.Refusal{code: :distributed_nodes_unreachable} = refusal} =
             Distributed.execute(plan, %{id: "chicago", capabilities: [:do]},
               nodes: [dead_node, node]
             )

    assert refusal.details.do_attempted == false
    assert dead_node in refusal.details.nodes
  end

  test "connection loss during a remote DO remains an ambiguous typed refusal" do
    peer = Ex4pm.Chicago.Cluster.start_peer!()
    node = elem(peer, 1)

    task = %{
      id: "slow",
      intent: %{operation: :slow_probe, mfa: {:timer, :sleep, [5_000]}}
    }

    {:ok, plan} = Runtime.compile(powl!([task], []))

    runner =
      Task.async(fn ->
        Distributed.execute(plan, %{id: "chicago", capabilities: [:do]},
          nodes: [node],
          timeout: 10_000
        )
      end)

    Process.sleep(150)
    :ok = Ex4pm.Chicago.Cluster.stop_peer(peer)

    assert {:error, error} = Task.await(runner, 15_000)
    assert {:ok, refusal} = find_refusal(error, :distributed_node_connection_lost)
    assert refusal.details.do_may_have_been_attempted == true
    assert refusal.details.node == node
  end

  test "remote application exceptions terminate in mirrored blocked receipts", %{
    nodes: [node | _]
  } do
    task = %{
      id: "explode",
      intent: %{operation: :explode, mfa: {:erlang, :error, [:chicago_boom]}}
    }

    {:ok, plan} = Runtime.compile(powl!([task], []))

    assert {:error, _error} =
             Distributed.execute(plan, %{id: "chicago", capabilities: [:do]},
               nodes: [node],
               timeout: 10_000
             )

    blocked =
      plan.subject_hash
      |> Store.get_by_subject()
      |> Enum.find(&(&1.phase == :outcome and &1.standing == :blocked))

    assert blocked
    assert {:ok, %{replay: :match}} = Replay.verify(blocked)
    assert {:ok, pending} = Store.get(blocked.parent_hash)
    assert pending.phase == :pending
    assert {:ok, %{replay: :match}} = Replay.verify(pending)
  end

  @tag :tmp_dir
  test "synchronous DETS receipts survive a store restart", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "receipts.dets")
    name = :ex4pm_chicago_durable_store
    table = :ex4pm_chicago_durable_table

    {:ok, pid} = DetsStore.start_link(name: name, table: table, path: path)

    assert {:ok, %{receipt: receipt}} =
             BRCE.execute(
               "subject",
               :durable_probe,
               %{id: "chicago", capabilities: [:do]},
               fn ->
                 %{persisted: true}
               end,
               store: name
             )

    :ok = GenServer.stop(pid)
    {:ok, pid2} = DetsStore.start_link(name: name, table: table, path: path)

    assert {:ok, persisted} = Store.get(receipt.hash, name)
    assert persisted == receipt
    assert {:ok, %{replay: :match}} = Replay.verify(persisted)

    :ok = GenServer.stop(pid2)
  end

  test "the supervised volatile evidence store is restarted after a crash" do
    old_pid = Process.whereis(Store)
    assert is_pid(old_pid)

    Process.exit(old_pid, :kill)

    wait_until(fn ->
      new_pid = Process.whereis(Store)
      is_pid(new_pid) and new_pid != old_pid
    end)

    assert {:ok, %{receipt: receipt}} =
             BRCE.execute(
               "restart-subject",
               :restart_probe,
               %{id: "chicago", capabilities: [:do]},
               fn ->
                 :after_restart
               end
             )

    assert {:ok, stored} = Store.get(receipt.hash)
    assert stored.hash == receipt.hash
  end

  test "tampering with a completed receipt is independently rejected" do
    assert {:ok, %{receipt: receipt}} =
             BRCE.execute(
               "tamper-subject",
               :tamper_probe,
               %{id: "chicago", capabilities: [:do]},
               fn ->
                 %{value: 42}
               end
             )

    tampered = %{receipt | artifact_hash: "sha256:deadbeef"}

    assert {:error, %Ex4pm.Refusal{code: :replay_mismatch}} = Replay.verify(tampered)
  end

  test "Broadway pressure preserves exact observation identity and acknowledgements" do
    event_count = 1_000

    events =
      for index <- 1..event_count do
        %Ex4pm.Event{
          id: "event-#{index}",
          activity: "observe",
          timestamp: "2026-08-21T00:00:00Z"
        }
      end

    {:ok, sink} = Agent.start_link(fn -> MapSet.new() end)

    pipeline =
      start_supervised!(
        {Ex4pm.Stream.Pipeline,
         name: :ex4pm_chicago_stream,
         events: events,
         sink: fn event -> Agent.update(sink, &MapSet.put(&1, event.id)) end,
         ack_target: self(),
         producer_concurrency: 1,
         processor_concurrency: 2,
         max_demand: 8,
         min_demand: 4}
      )

    assert is_pid(pipeline)
    assert collect_acks(event_count, 0) == event_count

    wait_until(fn -> Agent.get(sink, &MapSet.size/1) == event_count end)
    assert Agent.get(sink, &MapSet.size/1) == event_count
  end

  test "real Wasmtime execution remains inside the public receipted crown" do
    tmp_dir = System.tmp_dir!()
    path = Path.join(tmp_dir, "ex4pm-chicago-#{System.unique_integer([:positive])}.wat")

    File.write!(path, """
    (module
      (func $sum (param $left i32) (param $right i32) (result i32)
        local.get $left
        local.get $right
        i32.add)
      (export "sum" (func $sum)))
    """)

    on_exit(fn -> File.rm(path) end)

    model = %{
      type: :dfg,
      edges: %{{"a", "b"} => %{count: 1, average_duration_ms: 1}},
      starts: %{"a" => 1},
      ends: %{"b" => 1}
    }

    contract = %{
      simulate: %{
        export: "sum",
        params: [20, 22],
        algorithm: :chicago_wasm_probe,
        timeout: 5_000
      }
    }

    assert {:ok, run} =
             Ex4pm.simulate(model,
               engine: :wasm,
               wasm_path: path,
               wasm_contract: contract
             )

    assert run.value == [42]
    assert run.standing == :alive
    assert run.engine_result.evidence.runtime == :wasmex_wasmtime
    assert {:ok, %{replay: :match}} = Replay.verify(run.receipt)
  end

  test "distribution security never promotes a plain cookie network to global-production ALIVE" do
    posture = Distributed.security_posture()

    case posture.transport do
      transport when transport in [:inet_tls, :inet6_tls] ->
        assert posture.encrypted
        assert posture.production_network_standing == :partial_alive

      :inet_tcp ->
        refute posture.encrypted
        assert posture.production_network_standing == :blocked
        assert posture.reason == :plain_distribution_is_not_global_production_security
    end
  end

  defp powl!(tasks, edges) do
    {:ok, model} = POWL.new(tasks, edges)
    model
  end

  defp max_observed_overlap(intervals) do
    intervals
    |> Enum.flat_map(fn interval ->
      [
        {interval.started_us, 1},
        {interval.finished_us, -1}
      ]
    end)
    |> Enum.sort_by(fn {time, delta} -> {time, -delta} end)
    |> Enum.reduce({0, 0}, fn {_time, delta}, {active, peak} ->
      active = active + delta
      {active, max(peak, active)}
    end)
    |> elem(1)
  end

  defp find_refusal(%Ex4pm.Refusal{code: code} = refusal, code), do: {:ok, refusal}

  defp find_refusal(value, code) when is_map(value) do
    value
    |> Map.values()
    |> Enum.reduce_while(:error, fn nested, :error ->
      case find_refusal(nested, code) do
        {:ok, _refusal} = found -> {:halt, found}
        :error -> {:cont, :error}
      end
    end)
  end

  defp find_refusal(value, code) when is_list(value) do
    Enum.reduce_while(value, :error, fn nested, :error ->
      case find_refusal(nested, code) do
        {:ok, _refusal} = found -> {:halt, found}
        :error -> {:cont, :error}
      end
    end)
  end

  defp find_refusal(_value, _code), do: :error

  defp wait_until(fun, attempts \\ 100)

  defp wait_until(fun, attempts) when attempts > 0 do
    if fun.() do
      :ok
    else
      Process.sleep(25)
      wait_until(fun, attempts - 1)
    end
  end

  defp wait_until(_fun, 0), do: flunk("condition did not become true before timeout")

  defp collect_acks(expected, total) when total >= expected, do: total

  defp collect_acks(expected, total) do
    receive do
      {:ex4pm_stream_ack, successful, failed} ->
        assert failed == []
        collect_acks(expected, total + length(successful))
    after
      10_000 -> flunk("stream acknowledgements did not close")
    end
  end
end
