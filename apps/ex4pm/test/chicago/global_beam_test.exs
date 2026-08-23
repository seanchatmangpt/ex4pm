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
      Enum.map(nodes, fn node ->
        {
          :erpc.call(node, System, :otp_release, [], 15_000),
          :erpc.call(node, :erlang, :system_info, [:version], 15_000) |> to_string()
        }
      end)

    assert Enum.all?(remote_versions, fn {otp, erts} ->
             otp == observation.otp_release and erts == observation.erts_version
           end)
  end

  test "remote health is exact execution over live peers", %{nodes: nodes} do
    Enum.each(nodes, fn node ->
      assert {:ok, %{node: ^node, alive: true, application: :ex4pm_runtime}} =
               Distributed.health(node)
    end)
  end

  test "remote execute returns remote identity evidence", %{nodes: nodes} do
    Enum.each(nodes, fn node ->
      assert {:ok, result} =
               Distributed.execute(node, :process_count, fn ->
                 :erlang.system_info(:process_count)
               end)

      assert result.node == node
      assert result.operation == :process_count
      assert is_integer(result.value)
      assert result.value > 0
      assert result.evidence.executed
      assert result.evidence.runtime == :beam_distribution
      assert result.evidence.node == Atom.to_string(node)
      assert result.evidence.otp_release == System.otp_release()
      assert result.evidence.erts_version == to_string(:erlang.system_info(:version))
      assert result.evidence.subject_hash =~ "sha256:"
      assert result.evidence.result_hash =~ "sha256:"
    end)
  end

  test "remote subject bytes are replayable and tamper-evident", %{nodes: [node | _]} do
    subject = %{order: "A-42", quantity: 7, nested: %{priority: :high}}

    assert {:ok, result} =
             Distributed.execute(node, :echo_subject, fn -> subject end, subject: subject)

    assert result.value == subject
    assert result.evidence.subject_hash == Ex4pm.Evidence.Hash.digest(subject)
    assert result.evidence.result_hash == Ex4pm.Evidence.Hash.digest(subject)

    tampered = put_in(subject, [:nested, :priority], :low)
    refute Ex4pm.Evidence.Hash.digest(tampered) == result.evidence.subject_hash
  end

  test "remote failures remain typed and carry observed node identity", %{nodes: [node | _]} do
    assert {:error, {:remote_execution_failed, error}} =
             Distributed.execute(node, :explode, fn -> raise "boom" end)

    assert error.node == node
    assert error.operation == :explode
    assert error.kind == :error
    assert error.reason =~ "boom"
  end

  test "hard timeout bounds remote execution consequence", %{nodes: [node | _]} do
    started = System.monotonic_time(:millisecond)

    assert {:error, {:remote_execution_timeout, ^node, :slow, 50}} =
             Distributed.execute(node, :slow, fn -> Process.sleep(5_000) end, timeout: 50)

    elapsed = System.monotonic_time(:millisecond) - started
    assert elapsed < 4_000
  end

  test "remote execution cannot manufacture DO standing without BRCE", %{nodes: [node | _]} do
    assert {:ok, result} =
             Distributed.execute(node, :candidate, fn -> %{candidate: "ship", score: 0.99} end)

    assert result.standing == :partial_alive
    refute Map.has_key?(result, :receipt)
  end

  @tag :tmp_dir
  test "BRCE external callback emits pending and outcome receipts with chain replay", %{
    tmp_dir: tmp_dir
  } do
    path = Path.join(tmp_dir, "chicago-receipts.dets")
    assert {:ok, pid} = start_supervised({DetsStore, path: path})
    Store.put_backend(pid)

    request = %{
      subject: %{order: "A-42"},
      operation: :approve,
      requested_by: "chicago-court",
      capability: :external_mutation,
      authority: %{kind: :test, scope: "chicago"}
    }

    assert {:ok, result, outcome} = BRCE.execute(request, fn -> {:ok, %{approved: true}} end)
    assert result == %{approved: true}
    assert outcome.phase == :outcome
    assert outcome.status == :committed
    assert outcome.parent_hash

    assert {:ok, pending} = Store.fetch(outcome.parent_hash)
    assert pending.phase == :pending
    assert pending.status == :pending
    assert pending.hash == outcome.parent_hash

    assert {:ok, pending_replay} = Replay.verify(pending.hash)
    assert pending_replay.replay == :chain_match

    assert {:ok, outcome_replay} = Replay.verify(outcome.hash)
    assert outcome_replay.replay == :chain_match
    assert outcome_replay.depth >= 2
  end

  @tag :tmp_dir
  test "failed external callback emits a failed outcome receipt", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "chicago-failed-receipts.dets")
    assert {:ok, pid} = start_supervised({DetsStore, path: path})
    Store.put_backend(pid)

    request = %{
      subject: %{order: "B-9"},
      operation: :charge,
      requested_by: "chicago-court",
      capability: :external_mutation,
      authority: %{kind: :test, scope: "chicago"}
    }

    assert {:error, {:external_callback_failed, :network_down}, outcome} =
             BRCE.execute(request, fn -> {:error, :network_down} end)

    assert outcome.phase == :outcome
    assert outcome.status == :failed
    assert outcome.parent_hash
    assert {:ok, %{replay: :chain_match}} = Replay.verify(outcome.hash)
  end

  @tag :tmp_dir
  test "tampered persisted receipt is detected by replay", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "chicago-tamper-receipts.dets")
    assert {:ok, pid} = start_supervised({DetsStore, path: path})
    Store.put_backend(pid)

    assert {:ok, _result, outcome} =
             BRCE.execute(
               %{
                 subject: %{order: "C-1"},
                 operation: :persist,
                 requested_by: "chicago-court",
                 capability: :external_mutation,
                 authority: %{kind: :test, scope: "chicago"}
               },
               fn -> {:ok, :stored} end
             )

    assert {:ok, stored} = Store.fetch(outcome.hash)
    :ok = DetsStore.put(pid, %{stored | status: :failed})

    assert {:error, :hash_mismatch} = Replay.verify(outcome.hash)
  end

  test "POWL partial-order semantics survive execution on another BEAM", %{nodes: [node | _]} do
    model =
      POWL.sequence([
        POWL.activity(:admit),
        POWL.partial_order([POWL.activity(:left), POWL.activity(:right)], [{0, 1}]),
        POWL.activity(:receipt)
      ])

    assert {:ok, result} =
             Distributed.execute(node, :powl_linearize, fn -> POWL.linearize(model, limit: 20) end)

    assert result.value == [[:admit, :left, :right, :receipt]]
    assert result.evidence.executed
  end

  test "remote execution transports typed REFUSED without accidental success standing", %{
    nodes: [node | _]
  } do
    assert {:ok, result} =
             Distributed.execute(node, :typed_refusal, fn ->
               {:refused, :authority_missing, %{standing: :refused}}
             end)

    assert result.value == {:refused, :authority_missing, %{standing: :refused}}
    assert result.standing == :partial_alive
  end

  test "three peers agree on deterministic pure execution", %{nodes: nodes} do
    results =
      Enum.map(nodes, fn node ->
        {:ok, result} =
          Distributed.execute(node, :deterministic, fn ->
            Enum.reduce(1..10_000, 0, &+/2)
          end)

        result.value
      end)

    assert Enum.uniq(results) == [50_005_000]
  end
end
