defmodule Ex4pmCore.CapsuleCurrentnessABATest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.ABA

  test "same cut id at a later generation is refused" do
    a1 = %{cut_id: "A", generation: 1}
    b2 = %{cut_id: "B", generation: 2}
    a3 = %{cut_id: "A", generation: 3}
    assert :ok = ABA.detect([a1, b2])
    assert {:error, {:refused, :aba_context, %{cut_id: "A", before: 1, after: 3}}} = ABA.detect([a1, b2, a3])
  end
end
