defmodule Ex4pm.Develop.SearchPortfolioTest do
  use ExUnit.Case, async: true
  alias Ex4pm.Develop.Search.{Budget, Heuristic, PathCertificate, ResourceEnvelope, RolloutConsensus, Selector}

  test "search portfolio remains bounded and deterministic" do
    assert :ok = Budget.admit(%Budget{max_expansions: 10, max_cost: 20, max_depth: 4})
    assert Heuristic.consistent?([{:a,:b,1}], fn :a -> 1; :b -> 0 end)
    assert {:ok, %{cost: 3}} = PathCertificate.certify([:a,:b,:c], fn :a,:b -> 1; :b,:c -> 2 end)
    assert ResourceEnvelope.within?(%{expansions: 2, cost: 3, depth: 2}, %{max_expansions: 10, max_cost: 20, max_depth: 4})
    assert :x = RolloutConsensus.choose([:x,:y,:x])
    assert :min_cost in Selector.strategies()
  end
end
