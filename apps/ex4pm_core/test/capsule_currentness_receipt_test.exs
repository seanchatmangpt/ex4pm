defmodule Ex4pmCore.CapsuleCurrentnessReceiptTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.{Context, Receipt, Subject}

  test "receipt replay binds payload authority and no-actuation bit" do
    {:ok, subject} = Subject.new("owner/repo", String.duplicate("c", 40))
    {:ok, context, _} = Context.new(subject, 1, "cut", "policy", "frontier")
    admission = %{attempt: %{id: "attempt"}, context: context, standing: :partial_alive}
    receipt = Receipt.issue(admission)
    assert Receipt.replay(receipt)
    refute Receipt.replay(put_in(receipt.body.actuation_performed, true))
    refute Receipt.replay(put_in(receipt.body.authority, :do))
  end
end
