defmodule Ex4pmCore.CapsuleIndependenceGraphTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Independence.{IndependenceGraph, Provenance, Relation, Source}

  test "maximum clique counts only pairwise proven-independent clusters" do
    sha = String.duplicate("e", 40)
    {:ok, a} = Source.new("owner/repo@" <> sha, "p1", "r1", "a1", "f1")
    {:ok, b} = Source.new("owner/repo@" <> sha, "p2", "r2", "a2", "f2")
    {:ok, c} = Source.new("owner/repo@" <> sha, "p3", "r3", "a3", "f3")
    {:ok, provenance} = Provenance.new([])
    clusters = [[a], [b], [c]]

    one_edge = MapSet.new([Relation.canonical_pair(a.id, b.id)])
    assert length(IndependenceGraph.maximum_clique(clusters, provenance, one_edge)) == 2

    all_edges = MapSet.new([
      Relation.canonical_pair(a.id, b.id),
      Relation.canonical_pair(a.id, c.id),
      Relation.canonical_pair(b.id, c.id)
    ])
    assert length(IndependenceGraph.maximum_clique(clusters, provenance, all_edges)) == 3
  end
end
