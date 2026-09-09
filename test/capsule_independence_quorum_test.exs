defmodule Ex4pmCore.CapsuleIndependenceQuorumTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Independence.{Quorum, Source, Witness}

  test "positive quorum requires proven independent clusters and failure dominates" do
    sha = String.duplicate("f", 40)
    {:ok, a} = Source.new("owner/repo@" <> sha, "p1", "r1", "a1", "f1")
    {:ok, b} = Source.new("owner/repo@" <> sha, "p2", "r2", "a2", "f2")
    now = DateTime.utc_now()
    attempt = String.duplicate("1", 64)
    {:ok, wa} = Witness.new(a.id, attempt, :pass, :repository, now, "wa")
    {:ok, wb} = Witness.new(b.id, attempt, :pass, :repository, now, "wb")

    assert %{standing: :unknown} = Quorum.evaluate([[a], [b]], [wa, wb], 2, 1)
    assert %{standing: :partial_alive} = Quorum.evaluate([[a], [b]], [wa, wb], 2, 2)

    {:ok, failed} = Witness.new(b.id, attempt, :fail, :repository, now, "failed")
    assert %{standing: :build_broken} = Quorum.evaluate([[a], [b]], [wa, failed], 2, 2)
  end
end
