defmodule Ex4pm.Evidence.ReplayChainTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Core.Hash
  alias Ex4pm.Evidence.{Receipt, Store}
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
