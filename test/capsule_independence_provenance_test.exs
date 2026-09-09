defmodule Ex4pmCore.CapsuleIndependenceProvenanceTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Independence.Provenance

  test "provenance admits transitive derivation and refuses cycles" do
    assert {:ok, graph} = Provenance.new([{"a", "b"}, {"b", "c"}])
    assert Provenance.derived?(graph, "a", "c")
    refute Provenance.derived?(graph, "c", "a")
    assert {:error, {:refused, :provenance_cycle}} = Provenance.new([{"a", "b"}, {"b", "a"}])
  end
end
