defmodule Ex4pmCore.CapsuleGraph.ReceiptTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.{Candidate, Evidence, Receipt, Replay, Runtime, Subject, Transport}

  test "receipt is construct-only deterministic and tamper sensitive" do
    {:ok, subject} = Subject.new("seanchatmangpt/ex4pm-plan", String.duplicate("3", 40))
    {:ok, runtime} = Runtime.new(:oci, "v1", "linux-x86_64")
    {:ok, transport} = Transport.new(:oci, "sha256:image")
    {:ok, evidence} = Evidence.new(subject, :e2e, :pass, "run:1")
    {:ok, candidate} = Candidate.new("planner", subject, runtime, transport, [], [evidence])

    receipt = Receipt.new(candidate, %{b: 2, a: 1}, %{path: ["a", "b"]})
    assert receipt.authority == :construct_only
    assert {:ok, :match} = Replay.verify(receipt)

    assert {:error, {:refused, :capsule_receipt_mismatch}} =
             Replay.verify(%{receipt | output_digest: "tampered"})
  end
end
