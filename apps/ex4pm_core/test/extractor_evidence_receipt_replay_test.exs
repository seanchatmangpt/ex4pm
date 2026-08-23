defmodule Ex4pmCore.ExtractorEvidenceReceiptReplayTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.{Receipt, Replay}

  test "receipt replays only while source/output/authority binding is intact" do
    receipt = Receipt.new(:ash, "source", "output")
    assert {:ok, :match} = Replay.verify(receipt)

    assert {:error, {:refused, :receipt_mismatch}} =
             Replay.verify(%{receipt | output_digest: "tampered"})

    assert receipt.authority == :construct_only
  end
end
