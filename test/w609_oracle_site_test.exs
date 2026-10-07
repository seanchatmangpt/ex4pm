# W609 regression: dual-safe idiom at the reference_oracle visit-census site
# (w525d classification, W604 flag). Pins OBSERVED runtime behavior:
#   absent key  -> store 1 (intended first-visit count; fun NOT applied)
#   present key -> store count + 1
# Mirrors test/w604_map_update_dual_safe_test.exs idiom.

defmodule W609OracleSiteTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Qualification.Powl.ReferenceOracle

  test "canary: Map.update/4 skips fun on absent key on this runtime" do
    assert Map.update(%{}, :k, 7, &(&1 + 1)) == %{k: 7}
  end

  test "choice_graph loop: repeated node visitation respects the bound (absent key seeds 1)" do
    # Node "a" is revisited on every cycle; under documented Map.update semantics the
    # first visit would store 2 and the bound+1 visit budget would exhaust one step
    # early, truncating the trace set.
    graph = %Ex4pmEngine.POWL.ChoiceGraph{
      nodes: %{
        "a" => %Ex4pmEngine.POWL.Node{id: "a", operator: :activity, label: :a},
        "b" => %Ex4pmEngine.POWL.Node{id: "b", operator: :activity, label: :b}
      },
      edges: [{"▷", "a"}, {"a", "a"}, {"a", "b"}, {"b", "□"}]
    }

    model = %Ex4pmEngine.POWL.Node{
      id: "cg",
      operator: :choice_graph,
      choice_graph: graph
    }

    traces = ReferenceOracle.language(model, 2)
    assert traces == [["a", "a", "a", "b"], ["a", "a", "b"], ["a", "b"]]
    assert Enum.max(Enum.map(traces, &length/1)) == 4

    # Larger bound extends the language; any regression to early bound exhaustion
    # (documented Map.update semantics) would cap traces below this length.
    assert Enum.member?(ReferenceOracle.language(model, 3), ["a", "a", "a", "a", "b"])
  end
end
