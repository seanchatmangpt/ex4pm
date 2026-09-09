defmodule Ex4pmCore.CapsuleIndependenceReceiptTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Independence.{Receipt, Strategy}

  test "strategy remains selectable and receipts replay only without tampering or actuation" do
    result = Strategy.evaluate(:diversity_weighted, [:pass, :pass], {9, 5})
    assert result.score == {18, 5}
    assert result.standing == :partial_alive

    attempt = String.duplicate("2", 64)
    receipt = Receipt.issue(attempt, :partial_alive, {9, 5}, 2, [], :diversity_weighted)
    assert Receipt.replay(receipt)
    refute Receipt.replay(put_in(receipt.body.actuation_performed, true))
    refute Receipt.replay(put_in(receipt.body.standing, :alive))
  end
end
