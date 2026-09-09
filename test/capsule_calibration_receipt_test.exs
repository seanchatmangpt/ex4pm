defmodule Ex4pmCore.CapsuleCalibrationReceiptTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Calibration.Receipt

  test "replay binds payload, authority, and no-actuation" do
    receipt = Receipt.new(%{standing: :partial_alive, statistic: 2.0})
    assert Receipt.replay(receipt) == :match

    assert {:error, {:refused, :receipt_replay_mismatch}} =
             Receipt.replay(%{receipt | statistic: 3.0})

    assert {:error, {:refused, :invalid_or_actuating_receipt}} =
             Receipt.replay(%{receipt | actuation_performed: true})

    assert {:error, {:refused, :invalid_or_actuating_receipt}} =
             Receipt.replay(%{receipt | authority: :do})
  end
end
