defmodule Ex4pmCore.CapsuleIndependenceClustersTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Independence.{Clusters, Diversity, Provenance, Source}

  test "two correlated sources plus one separate source have exact diversity 9/5" do
    sha = String.duplicate("d", 40)
    {:ok, a} = Source.new("owner/repo@" <> sha, "p1", "r1", "a1", "shared")
    {:ok, b} = Source.new("owner/repo@" <> sha, "p2", "r2", "a2", "shared")
    {:ok, c} = Source.new("owner/repo@" <> sha, "p3", "r3", "a3", "other")
    {:ok, provenance} = Provenance.new([])

    clusters = Clusters.build([a, b, c], provenance)
    assert Enum.sort(Enum.map(clusters, &length/1)) == [1, 2]
    assert Diversity.effective(clusters) == {9, 5}
  end
end
