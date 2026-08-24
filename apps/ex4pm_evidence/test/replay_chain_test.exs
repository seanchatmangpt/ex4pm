defmodule Ex4pm.Evidence.ReplayChainTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Core.Hash
  alias Ex4pm.Evidence.{Receipt, Replay, Store}
  alias Ex4pm.Evidence.Replay.Chain

  setup do
    start_supervised!({Store, name: :replay_chain_test_store})
    :ok
  end

  test "valid outcome replay closes over its pending parent" do
    pending = Receipt.pending("sha256:subject", :analyze, %{capabilities: [:do]})
    outcome = Receipt.outcome(pending, %{value: 42}, :alive)

    assert {:ok, _} = Store.put(pending, :replay_chain_test_store)
    assert {:ok, _} = Store.put(outcome, :replay_chain_test_store)

    assert {:ok, %{replay: :chain_match, standing: :alive, parent: ^pending, receipt: ^outcome}} =
             Chain.verify(outcome, :replay_chain_test_store)
  end

  test "outcome replay refuses an orphaned parent" do
    pending = Receipt.pending("sha256:subject", :analyze, nil)
    outcome = Receipt.outcome(pending, :ok, :alive)

    assert {:ok, _} = Store.put(outcome, :replay_chain_test_store)

    assert {:error, %Ex4pm.Refusal{code: :receipt_parent_not_found}} =
             Chain.verify(outcome, :replay_chain_test_store)
  end

  test "outcome replay refuses a self-consistent child bound to the wrong pending subject" do
    original_parent = Receipt.pending("sha256:subject-a", :analyze, nil)
    wrong_parent = Receipt.pending("sha256:subject-b", :analyze, nil)

    outcome =
      original_parent
      |> Receipt.outcome(:ok, :alive)
      |> reparent(wrong_parent.hash)

    assert {:ok, _} = Store.put(wrong_parent, :replay_chain_test_store)
    assert {:ok, _} = Store.put(outcome, :replay_chain_test_store)

    assert {:error,
            %Ex4pm.Refusal{
              code: :receipt_parent_mismatch,
              details: %{
                mismatches: %{
                  subject_hash: %{pending: "sha256:subject-b", outcome: "sha256:subject-a"}
                }
              }
            }} = Chain.verify(outcome, :replay_chain_test_store)
  end

  test "pending replay remains envelope-verifiable without a parent" do
    pending = Receipt.pending("sha256:subject", :analyze, nil)

    assert {:ok, %{replay: :match, receipt: ^pending}} =
             Chain.verify(pending, :replay_chain_test_store)
  end

  test "outcome replay refuses a parent that is itself an outcome, not a pending (phase guard)" do
    grandparent_pending = Receipt.pending(Faker.UUID.v4(), :analyze, nil)
    not_actually_pending = Receipt.outcome(grandparent_pending, :ok, :alive)

    own_pending = Receipt.pending(Faker.UUID.v4(), :analyze, nil)

    outcome =
      own_pending
      |> Receipt.outcome(:ok, :alive)
      |> reparent(not_actually_pending.hash)

    assert {:ok, _} = Store.put(not_actually_pending, :replay_chain_test_store)
    assert {:ok, _} = Store.put(outcome, :replay_chain_test_store)

    assert {:error, %Ex4pm.Refusal{code: :receipt_parent_invalid_phase}} =
             Chain.verify(outcome, :replay_chain_test_store)
  end

  test "chain verification catches a stored pending parent tampered after the fact, even though the outcome that references it is itself untouched" do
    pending = Receipt.pending(Faker.UUID.v4(), :analyze, %{capabilities: [:do]})
    outcome = Receipt.outcome(pending, %{value: Faker.random_between(1, 1000)}, :alive)

    assert {:ok, _} = Store.put(pending, :replay_chain_test_store)
    assert {:ok, _} = Store.put(outcome, :replay_chain_test_store)

    # Sanity: the untampered chain verifies.
    assert {:ok, %{replay: :chain_match}} = Chain.verify(outcome, :replay_chain_test_store)

    # Now tamper the *stored* pending receipt directly (simulating a ledger-level attack that
    # doesn't touch the outcome at all) and overwrite it in the store.
    tampered_pending = %{pending | subject_hash: Faker.UUID.v4()}
    assert {:ok, _} = Store.put(tampered_pending, :replay_chain_test_store)

    assert {:error, %Ex4pm.Refusal{code: :replay_mismatch}} =
             Chain.verify(outcome, :replay_chain_test_store)
  end

  test "Chain.verify/2 and Replay.verify/1 both refuse a receipt-shaped map instead of crashing" do
    receipt_shaped_map = %{
      phase: :outcome,
      subject_hash: Faker.UUID.v4(),
      hash: Faker.UUID.v4()
    }

    assert {:error, %Ex4pm.Refusal{code: :invalid_receipt}} =
             Chain.verify(receipt_shaped_map, :replay_chain_test_store)

    assert {:error, %Ex4pm.Refusal{code: :invalid_receipt}} = Replay.verify(receipt_shaped_map)
    assert {:error, %Ex4pm.Refusal{code: :invalid_receipt}} = Replay.verify(nil)
  end

  defp reparent(outcome, parent_hash) do
    outcome = %{outcome | parent_hash: parent_hash}

    hash =
      Hash.digest(%{
        phase: :outcome,
        parent_hash: outcome.parent_hash,
        subject_hash: outcome.subject_hash,
        operation: outcome.operation,
        authority_hash: outcome.authority_hash,
        artifact_hash: outcome.artifact_hash,
        standing: outcome.standing,
        finished_at: outcome.finished_at,
        metadata: outcome.metadata
      })

    %{outcome | hash: hash}
  end
end
