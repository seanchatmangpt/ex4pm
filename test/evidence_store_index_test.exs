defmodule Ex4pm.Evidence.StoreIndexTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Evidence.{Receipt, Store}

  setup do
    {:ok, store} = start_supervised({Store, [name: :evidence_store_index_test]})
    %{store: store}
  end

  test "maintains an indexed subject lookup independent of total ledger size", %{store: store} do
    target_subject = "sha256:target"

    Enum.each(1..1_000, fn n ->
      pending =
        Receipt.pending("sha256:noise-#{n}", {:noise, n}, nil, %{sequence: n})

      assert {:ok, ^pending} = Store.put(pending, store)
    end)

    pending = Receipt.pending(target_subject, :ingest, nil, %{sequence: 1})
    outcome = Receipt.outcome(pending, %{status: :ingested}, :alive, %{sequence: 1})

    assert {:ok, ^pending} = Store.put(pending, store)
    assert {:ok, ^outcome} = Store.put(outcome, store)

    receipts = Store.get_by_subject(target_subject, store)

    assert MapSet.new(Enum.map(receipts, & &1.hash)) ==
             MapSet.new([pending.hash, outcome.hash])

    assert Enum.all?(receipts, &(&1.subject_hash == target_subject))

    state = :sys.get_state(store)

    assert Map.has_key?(state, :subject_index)
    assert :ets.lookup(state.subject_index, target_subject) |> length() == 2
    assert :ets.info(state.table, :size) == 1_002
  end

  test "maintains the parent index and removes stale index entries on hash replacement", %{
    store: store
  } do
    pending = Receipt.pending("sha256:subject-a", :ship, nil)
    outcome = Receipt.outcome(pending, :done, :alive)

    assert {:ok, ^pending} = Store.put(pending, store)
    assert {:ok, ^outcome} = Store.put(outcome, store)

    assert [found] = Store.get_by_parent(pending.hash, store)
    assert found.hash == outcome.hash

    replacement = %{outcome | subject_hash: "sha256:subject-b", parent_hash: nil}

    assert {:ok, ^replacement} = Store.put(replacement, store)

    assert Store.get_by_parent(pending.hash, store) == []
    assert Store.get_by_subject("sha256:subject-a", store) == [pending]
    assert [found_replacement] = Store.get_by_subject("sha256:subject-b", store)
    assert found_replacement.hash == outcome.hash

    state = :sys.get_state(store)
    assert :ets.lookup(state.parent_index, pending.hash) == []
  end
end
