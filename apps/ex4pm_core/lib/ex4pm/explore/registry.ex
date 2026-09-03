defmodule Ex4pm.Explore.Registry do
  @moduledoc false

  @candidates [
    %{id: :pareto, family: :multi_objective, module: Ex4pm.Explore.Pareto, assumptions: [:higher_is_better], rollback: :trivial},
    %{id: :weighted_sum, family: :multi_objective, module: Ex4pm.Explore.WeightedSum, assumptions: [:commensurable_scores], rollback: :trivial},
    %{id: :lexicographic, family: :multi_objective, module: Ex4pm.Explore.Lexicographic, assumptions: [:ordered_priorities], rollback: :trivial},
    %{id: :ucb1, family: :bandit, module: Ex4pm.Explore.UCB1, assumptions: [:stationary_rewards], rollback: :trivial},
    %{id: :uct, family: :tree_search, module: Ex4pm.Explore.UCT, assumptions: [:bounded_rollout_value], rollback: :trivial},
    %{id: :dijkstra, family: :graph_search, module: Ex4pm.Explore.Dijkstra, assumptions: [:nonnegative_edges], rollback: :trivial},
    %{id: :bellman_ford, family: :graph_search, module: Ex4pm.Explore.BellmanFord, assumptions: [:finite_graph], rollback: :trivial},
    %{id: :floyd_warshall, family: :graph_search, module: Ex4pm.Explore.FloydWarshall, assumptions: [:finite_graph], rollback: :trivial},
    %{id: :vector_clock, family: :distributed_order, module: Ex4pm.Explore.VectorClock, assumptions: [:actor_identity], rollback: :trivial},
    %{id: :quorum, family: :distributed_safety, module: Ex4pm.Explore.Quorum, assumptions: [:fixed_replica_count], rollback: :trivial},
    %{id: :temporal_monitor, family: :runtime_verification, module: Ex4pm.Explore.TemporalMonitor, assumptions: [:bounded_trace], rollback: :trivial}
  ]

  def all, do: @candidates
  def by_family(family), do: Enum.filter(@candidates, &(&1.family == family))
  def fetch(id), do: Enum.find(@candidates, &(&1.id == id))
end
