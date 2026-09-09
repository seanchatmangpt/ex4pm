defmodule Ex4pmCore.CapsuleIndependenceRelationTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Independence.{Provenance, Relation, Source}

  test "shared source family correlates unless explicit independence is admitted" do
    sha = String.duplicate("c", 40)
    {:ok, left} = Source.new("owner/repo@" <> sha, "p1", "r1", "a1", "family")
    {:ok, right} = Source.new("owner/repo@" <> sha, "p2", "r2", "a2", "family")
    {:ok, provenance} = Provenance.new([])

    assert Relation.classify(left, right, provenance) == :correlated
    pair = Relation.canonical_pair(left.id, right.id)
    assert Relation.classify(left, right, provenance, MapSet.new([pair])) == :independent
  end
end
