defmodule Ex4pmCore.CapsuleIndependenceEngineTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Currentness.{Attempt, Context, Engine, Lease, Subject, Witness}
  alias Ex4pmCore.CapsuleGraph.Independence.{Engine, Provenance, Relation, Source}
  alias Ex4pmCore.CapsuleGraph.Independence.Witness, as: EvidenceWitness

  test "current capsule needs independent evidence and moved context invalidates the predecessor attempt" do
    {:ok, subject} = Subject.new("owner/repo", String.duplicate("9", 40))
    {:ok, context, digest} = Context.new(subject, 1, "cut-a", "policy", "frontier")
    {:ok, lease} = Lease.new(10, 20)
    {:ok, attempt} = Attempt.new(subject, digest, digest, 1, "nonce", lease)
    {:ok, currentness_witness} = Witness.new(digest, digest, :exact, :pass)
    assert {:ok, %{replay: true}} = Engine.qualify(attempt, [context], currentness_witness, 15)

    exact_subject = "owner/repo@" <> String.duplicate("9", 40)
    {:ok, a} = Source.new(exact_subject, "producer-a", "run-a", "artifact-a", "family-a")
    {:ok, b} = Source.new(exact_subject, "producer-b", "run-b", "artifact-b", "family-b")
    now = DateTime.utc_now()
    {:ok, wa} = EvidenceWitness.new(a.id, attempt.id, :pass, :repository, now, "wa")
    {:ok, wb} = EvidenceWitness.new(b.id, attempt.id, :pass, :runtime, now, "wb")
    {:ok, provenance} = Provenance.new([])

    assert {:ok, %{standing: :unknown}} =
             Ex4pmCore.CapsuleGraph.Independence.Engine.qualify([a, b], [wa, wb], provenance, MapSet.new(), attempt.id, now, 2)

    independent = MapSet.new([Relation.canonical_pair(a.id, b.id)])
    assert {:ok, %{standing: :partial_alive, replay: true, actuation_performed: false}} =
             Ex4pmCore.CapsuleGraph.Independence.Engine.qualify([a, b], [wa, wb], provenance, independent, attempt.id, now, 2)

    {:ok, moved, moved_digest} = Context.new(subject, 2, "cut-b", "policy", "frontier")
    {:ok, moved_witness} = Witness.new(moved_digest, moved_digest, :exact, :pass)
    assert {:error, {:refused, :stale_target}} = Engine.qualify(attempt, [moved], moved_witness, 15)
  end
end
