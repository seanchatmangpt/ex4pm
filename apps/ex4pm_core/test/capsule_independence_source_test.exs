defmodule Ex4pmCore.CapsuleIndependenceSourceTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Independence.{Source, Witness}

  test "source and witness require exact bounded identities" do
    sha = String.duplicate("a", 40)
    assert {:error, {:refused, :inexact_subject}} = Source.new("owner/repo@main", "p", "r", "a", "f")
    assert {:ok, source} = Source.new("owner/repo@" <> sha, "producer", "run", "artifact", "family")
    assert byte_size(source.id) == 64

    now = DateTime.utc_now()
    attempt = String.duplicate("b", 64)
    assert {:ok, witness} = Witness.new(source.id, attempt, :pass, :repository, now, "evidence-1")
    assert witness.source_id == source.id
    assert {:error, {:refused, :invalid_evidence_scope}} = Witness.new(source.id, attempt, :pass, :planet, now, "bad")
  end
end
