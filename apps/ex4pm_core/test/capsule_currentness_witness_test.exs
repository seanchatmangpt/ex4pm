defmodule Ex4pmCore.CapsuleCurrentnessWitnessTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.Witness

  test "exact witness requires identical context digests" do
    assert {:ok, %Witness{kind: :exact, result: :pass}} =
             Witness.new("same", "same", :exact, :pass)

    assert {:error, {:refused, :false_exact_witness}} =
             Witness.new("before", "after", :exact, :pass)

    assert {:ok, %Witness{kind: :semantic_equivalent}} =
             Witness.new("before", "after", :semantic_equivalent, :pass)
  end
end
