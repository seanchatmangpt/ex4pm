defmodule Ex4pm.ExploreMethodologyClosureTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Explore.{DifferentialComparator, Hypergraph, Markov, Pareto, PowlUnfold, ReplayChain, TemporalLogic, TokenReplay, Trajectory}

  test "preserves multiple equivalent implementations until differential comparison" do
    implementations = %{direct: &Enum.sum/1, folded: &Enum.reduce(&1, 0, fn x, acc -> x + acc end)}
    assert {:equivalent, %{direct: 6, folded: 6}} = DifferentialComparator.compare([1, 2, 3], implementations)
  end

  test "directed hypergraph closure requires all source vertices" do
    edges = [%{from: [:a, :b], to: [:c]}, %{from: [:c], to: [:d]}]
    assert Hypergraph.closure([:a], edges) == MapSet.new([:a])
    assert Hypergraph.closure([:a, :b], edges) == MapSet.new([:a, :b, :c, :d])
  end

  test "bounded cyclic POWL unfolding terminates by semantic bound" do
    graph = %{a: [:b], b: [:a]}
    assert PowlUnfold.unfold(:a, &Map.fetch!(graph, &1), 2) == [a: 0, b: 1, a: 2]
  end

  test "token replay leaves a falsifiable nonconformance witness" do
    transitions = %{{:s0, :a} => :s1}
    assert {:error, {:nonconformant, :b, :s1, [:a]}} = TokenReplay.replay([:a, :b], transitions, :s0)
  end

  test "receipt replay detects mutation" do
    chain = [] |> ReplayChain.append(%{event: 1}) |> ReplayChain.append(%{event: 2})
    assert ReplayChain.verify(chain)
    [first, second] = chain
    refute ReplayChain.verify([first, %{second | payload: %{event: 3}}])
  end

  test "eventual/always and discrete trajectory semantics remain independently executable" do
    assert TemporalLogic.always([2, 4, 6], &(rem(&1, 2) == 0))
    assert TemporalLogic.eventually([1, 3, 4], &(rem(&1, 2) == 0))
    assert Trajectory.differences([1, 4, 9]) == [3, 5]
  end

  test "Markov projection and Pareto frontier retain distinct selection semantics" do
    matrix = Markov.fit([{:a, :b}, {:a, :b}, {:a, :c}])
    assert {:ok, :b, probability} = Markov.predict(:a, matrix)
    assert_in_delta probability, 2 / 3, 1.0e-9

    candidates = [%{id: :x, quality: 10, cost: 4}, %{id: :y, quality: 8, cost: 2}, %{id: :z, quality: 7, cost: 5}]
    ids = candidates |> Pareto.frontier([quality: :max, cost: :min]) |> Enum.map(& &1.id) |> MapSet.new()
    assert ids == MapSet.new([:x, :y])
  end
end
