defmodule Ex4pm.ReplayTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Evidence.{Receipt, Store}

  setup do
    start_supervised!({Store, name: :public_replay_test_store})
    :ok
  end

  test "public replay verifies the outcome and its pending parent" do
    pending = Receipt.pending("sha256:subject", {:analysis, :discover}, nil)
    outcome = Receipt.outcome(pending, %{model: :dfg}, :alive)

    assert {:ok, _} = Store.put(pending, :public_replay_test_store)
    assert {:ok, _} = Store.put(outcome, :public_replay_test_store)

    assert {:ok, %{replay: :chain_match, parent: ^pending, receipt: ^outcome}} =
             Ex4pm.replay(outcome.hash, store: :public_replay_test_store)
  end

  test "public replay refuses an outcome whose parent is absent" do
    pending = Receipt.pending("sha256:subject", {:analysis, :discover}, nil)
    outcome = Receipt.outcome(pending, %{model: :dfg}, :alive)

    assert {:ok, _} = Store.put(outcome, :public_replay_test_store)

    assert {:error, %Ex4pm.Refusal{code: :receipt_parent_not_found}} =
             Ex4pm.replay(outcome.hash, store: :public_replay_test_store)
  end
end
