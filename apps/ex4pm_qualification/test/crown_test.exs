defmodule Ex4pm.Qualification.CrownTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Qualification.Powl.Correspondence
  alias Ex4pm.Qualification.Verifier
  alias Ex4pmEngine.POWL

  test "bounded correspondence covers sequence, choice, partial order, loop and choice graph" do
    assert {:ok, evidence} = Correspondence.court()
    assert evidence.models >= 7
    assert evidence.traces > 0
    assert Enum.all?(evidence.certificates, &(&1.soundness and &1.completeness and &1.compiler_refinement))
  end

  test "court detects exact trace-language sabotage" do
    model = POWL.sequence("s", [POWL.activity("a", "A"), POWL.activity("b", "B")])
    for mutation <- [:extra_trace, :missing_trace, :wrong_order, :duplicate_execution, :lost_terminal, :wrong_bound] do
      assert :detected = Correspondence.sabotage(model, 2, mutation)
    end
  end

  test "standing is recomputed and stored ALIVE cannot override missing evidence" do
    bad = %{"standing" => "ALIVE", "source_sha" => String.duplicate("a", 40), "tree_sha" => String.duplicate("b", 40)}
    assert {:error, %{standing: :partial_alive}} = Verifier.verify(bad)
  end
end
