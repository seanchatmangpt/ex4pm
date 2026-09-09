defmodule Ex4pmCore.CapsuleCurrentnessEngineTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.{Attempt, Context, Engine, Lease, Subject, Witness}

  test "exact current recovery constructs replayable non-actuating evidence and stale target refuses" do
    {:ok, subject} = Subject.new("owner/repo", String.duplicate("d", 40))
    {:ok, context, digest} = Context.new(subject, 1, "cut-a", "policy", "frontier")
    {:ok, lease} = Lease.new(10, 20)
    {:ok, attempt} = Attempt.new(subject, digest, digest, 1, "nonce", lease)
    {:ok, witness} = Witness.new(digest, digest, :exact, :pass)

    assert {:ok, %{replay: true, actuation_performed: false, receipt: receipt}} =
             Engine.qualify(attempt, [context], witness, 15)

    assert receipt.body.authority == :construct

    {:ok, moved, moved_digest} = Context.new(subject, 2, "cut-b", "policy", "frontier")
    {:ok, moved_witness} = Witness.new(moved_digest, moved_digest, :exact, :pass)

    assert {:error, {:refused, :stale_target}} =
             Engine.qualify(attempt, [moved], moved_witness, 15)
  end
end
