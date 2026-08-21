defmodule Ex4pm.EvidenceTest.FailingStore do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, Keyword.fetch!(opts, :fail_on),
      name: Keyword.fetch!(opts, :name)
    )
  end

  @impl true
  def init(fail_on), do: {:ok, fail_on}

  @impl true
  def handle_call({:put, %{phase: phase}}, _from, phase) do
    {:reply, {:error, {:simulated_persistence_failure, phase}}, phase}
  end

  def handle_call({:put, receipt}, _from, state), do: {:reply, {:ok, receipt}, state}
  def handle_call({:get, _hash}, _from, state), do: {:reply, :error, state}
  def handle_call(:all, _from, state), do: {:reply, [], state}
end

defmodule Ex4pm.EvidenceTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Evidence.{BRCE, Replay, Store}
  alias Ex4pm.EvidenceTest.FailingStore

  setup do
    start_supervised!({Store, name: :evidence_test_store})
    :ok
  end

  test "BRCE refuses missing authority without invoking DO" do
    parent = self()

    assert {:error, %Ex4pm.Refusal{code: :authority_required}} =
             BRCE.execute("sha256:subject", :ship, nil, fn -> send(parent, :invoked) end,
               store: :evidence_test_store
             )

    refute_received :invoked
    assert Store.all(:evidence_test_store) == []
  end

  test "BRCE writes pending and outcome receipts and replay closes" do
    authority = %{id: "test", capabilities: [:do]}

    assert {:ok, %{result: 42, pending: pending, receipt: outcome}} =
             BRCE.execute("sha256:subject", :calculate, authority, fn -> 42 end,
               store: :evidence_test_store
             )

    assert pending.phase == :pending
    assert outcome.phase == :outcome
    assert outcome.parent_hash == pending.hash
    assert {:ok, %{replay: :match}} = Replay.verify(pending)
    assert {:ok, %{replay: :match, standing: :alive}} = Replay.verify(outcome)
    assert length(Store.all(:evidence_test_store)) == 2
  end

  test "BRCE never invokes DO when the pending receipt cannot persist" do
    parent = self()

    start_supervised!({FailingStore, name: :pending_failure_store, fail_on: :pending})

    assert {:error, %Ex4pm.Refusal{code: :pending_receipt_persistence_failed}} =
             BRCE.execute(
               "sha256:subject",
               :ship,
               %{capabilities: [:do]},
               fn -> send(parent, :invoked) end,
               store: :pending_failure_store
             )

    refute_received :invoked
  end

  test "BRCE reports an explicit receipt failure when outcome persistence fails after DO" do
    parent = self()

    start_supervised!({FailingStore, name: :outcome_failure_store, fail_on: :outcome})

    assert {:error,
            %Ex4pm.Refusal{
              code: :outcome_receipt_persistence_failed,
              details: %{do_attempted: true}
            }} =
             BRCE.execute(
               "sha256:subject",
               :ship,
               %{capabilities: [:do]},
               fn ->
                 send(parent, :invoked)
                 :shipped
               end,
               store: :outcome_failure_store
             )

    assert_received :invoked
  end
end
