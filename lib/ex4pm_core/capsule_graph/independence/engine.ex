defmodule Ex4pmCore.CapsuleGraph.Independence.Engine do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.Independence.{
    Clusters,
    Dependency,
    Diversity,
    Frontier,
    IndependenceGraph,
    Quorum,
    Receipt,
    Standing,
    Strategy
  }

  def qualify(
        sources,
        witnesses,
        provenance,
        independent_pairs,
        attempt_id,
        now,
        minimum,
        dependencies \\ %{},
        dependency_standings \\ %{},
        strategy \\ :cluster_majority
      ) do
    with {:ok, frontier} <- Frontier.build(witnesses, attempt_id, now),
         current_source_ids <- MapSet.new(frontier.current, & &1.source_id),
         current_sources <- Enum.filter(sources, &MapSet.member?(current_source_ids, &1.id)),
         clusters <- Clusters.build(current_sources, provenance, independent_pairs),
         independent_clique <-
           IndependenceGraph.maximum_clique(clusters, provenance, independent_pairs),
         diversity <- Diversity.effective(clusters),
         quorum <-
           Quorum.evaluate(clusters, frontier.current, minimum, length(independent_clique)),
         {:ok, blockers} <- Dependency.blockers(dependencies, dependency_standings),
         strategy_result when is_map(strategy_result) <-
           Strategy.evaluate(strategy, quorum.cluster_outcomes, diversity) do
      standing =
        [
          quorum.standing,
          strategy_result.standing,
          if(blockers == [], do: :partial_alive, else: :blocked)
        ]
        |> Standing.combine()
        |> Standing.cap_positive()

      receipt =
        Receipt.issue(attempt_id, standing, diversity, length(clusters), blockers, strategy)

      {:ok,
       %{
         standing: standing,
         clusters: clusters,
         independent_clique: independent_clique,
         diversity: diversity,
         quorum: quorum,
         strategy: strategy_result,
         current_evidence: frontier.current,
         historical_evidence: frontier.historical,
         blockers: blockers,
         receipt: receipt,
         replay: Receipt.replay(receipt),
         actuation_performed: false
       }}
    else
      {:error, _} = error -> error
    end
  end
end
