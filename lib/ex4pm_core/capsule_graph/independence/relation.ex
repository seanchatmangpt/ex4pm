defmodule Ex4pmCore.CapsuleGraph.Independence.Relation do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Independence.Provenance

  def classify(left, right, provenance, independent_pairs \\ MapSet.new()) do
    pair = canonical_pair(left.id, right.id)

    cond do
      left.id == right.id -> :same_evidence
      Provenance.derived?(provenance, left.id, right.id) -> :correlated
      Provenance.derived?(provenance, right.id, left.id) -> :correlated
      MapSet.member?(independent_pairs, pair) -> :independent
      left.producer == right.producer -> :correlated
      left.run == right.run -> :correlated
      left.artifact == right.artifact -> :correlated
      left.family == right.family -> :correlated
      true -> :unknown
    end
  end

  def canonical_pair(a, b) when a <= b, do: {a, b}
  def canonical_pair(a, b), do: {b, a}
end
