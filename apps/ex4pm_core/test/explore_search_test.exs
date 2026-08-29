defmodule Ex4pm.Explore.SearchTest do
  use ExUnit.Case, async: true

  test "Dijkstra and Bellman-Ford agree on nonnegative graph" do
    nodes = [:a, :b, :c]
    edges = [{:a, :b, 2}, {:b, :c, 3}, {:a, :c, 10}]
    dijkstra = Ex4pm.Explore.Dijkstra.shortest(nodes, edges, :a)
    assert {:ok, bellman} = Ex4pm.Explore.BellmanFord.shortest(nodes, edges, :a)
    assert dijkstra == bellman
    assert dijkstra[:c] == 5
  end

  test "Floyd-Warshall agrees on same shortest path" do
    dist = Ex4pm.Explore.FloydWarshall.all_pairs([:a, :b, :c], [{:a, :b, 2}, {:b, :c, 3}, {:a, :c, 10}])
    assert dist[{:a, :c}] == 5
  end
end
