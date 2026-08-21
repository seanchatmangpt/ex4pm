
defmodule Ex4pm.EvidenceTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Evidence.{BRCE, Replay, Store}

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
end
