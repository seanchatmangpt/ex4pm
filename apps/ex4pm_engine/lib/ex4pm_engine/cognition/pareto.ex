defmodule Ex4pmEngine.Cognition.Pareto do
  @moduledoc """
  Multi-objective Pareto dominance ranking over competing candidate process models.
  Computes non-dominated frontiers across fitness, precision, cost, and complexity objectives.
  """

  @doc """
  Evaluates a list of candidates against multiple objectives.
  `candidates` is a list of maps, e.g. `[%{id: "m1", fitness: 0.9, precision: 0.85, cost: 12.0}, ...]`.
  `objectives` is a list of `{key, :maximize | :minimize}`.

  Returns the non-dominated Pareto frontier and ranked tiers.
  """
  def compute_frontier(candidates, objectives) when is_list(candidates) and is_list(objectives) do
    # For each candidate, find who dominates whom
    dominated_by_counts =
      Map.new(candidates, fn c ->
        dominators_count =
          Enum.count(candidates, fn other ->
            other != c and dominates?(other, c, objectives)
          end)

        {c, dominators_count}
      end)

    # Tier 0 (frontier) are candidates with 0 dominators
    frontier =
      Enum.filter(candidates, fn c -> Map.get(dominated_by_counts, c) == 0 end)

    ranked_tiers =
      candidates
      |> Enum.group_by(fn c -> Map.get(dominated_by_counts, c) end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))

    %{
      frontier: frontier,
      total_candidates: length(candidates),
      frontier_size: length(frontier),
      tiers: ranked_tiers
    }
  end

  @doc "Checks if candidate A strictly Pareto dominates candidate B."
  def dominates?(cand_a, cand_b, objectives) do
    strictly_better_in_at_least_one? =
      Enum.any?(objectives, fn {key, direction} ->
        val_a = Map.get(cand_a, key) || Map.get(cand_a, to_string(key), 0.0)
        val_b = Map.get(cand_b, key) || Map.get(cand_b, to_string(key), 0.0)

        case direction do
          :maximize -> val_a > val_b
          :minimize -> val_a < val_b
        end
      end)

    no_worse_in_any? =
      Enum.all?(objectives, fn {key, direction} ->
        val_a = Map.get(cand_a, key) || Map.get(cand_a, to_string(key), 0.0)
        val_b = Map.get(cand_b, key) || Map.get(cand_b, to_string(key), 0.0)

        case direction do
          :maximize -> val_a >= val_b
          :minimize -> val_a <= val_b
        end
      end)

    strictly_better_in_at_least_one? and no_worse_in_any?
  end
end
