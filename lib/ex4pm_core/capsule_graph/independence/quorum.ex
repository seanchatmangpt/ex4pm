defmodule Ex4pmCore.CapsuleGraph.Independence.Quorum do
  @moduledoc false

  def evaluate(clusters, witnesses, minimum, proven_independent_count)
      when is_list(clusters) and is_list(witnesses) and is_integer(minimum) and minimum > 0 and
             is_integer(proven_independent_count) and proven_independent_count >= 0 do
    by_source = Map.new(witnesses, &{&1.source_id, &1})
    outcomes = Enum.map(clusters, &cluster_outcome(&1, by_source))
    passes = Enum.count(outcomes, &(&1 == :pass))

    cond do
      :fail in outcomes ->
        %{
          standing: :build_broken,
          pass_clusters: passes,
          independent_clusters: proven_independent_count,
          cluster_outcomes: outcomes
        }

      Enum.all?(outcomes, &(&1 == :unsupported)) ->
        %{
          standing: :unsupported,
          pass_clusters: passes,
          independent_clusters: proven_independent_count,
          cluster_outcomes: outcomes
        }

      passes >= minimum and proven_independent_count >= minimum ->
        %{
          standing: :partial_alive,
          pass_clusters: passes,
          independent_clusters: proven_independent_count,
          cluster_outcomes: outcomes
        }

      true ->
        %{
          standing: :unknown,
          pass_clusters: passes,
          independent_clusters: proven_independent_count,
          cluster_outcomes: outcomes
        }
    end
  end

  def evaluate(_, _, _, _),
    do: %{standing: :unknown, pass_clusters: 0, independent_clusters: 0, cluster_outcomes: []}

  defp cluster_outcome(cluster, by_source) do
    outcomes =
      Enum.map(cluster, fn source ->
        Map.get(by_source, source.id, %{outcome: :unknown}).outcome
      end)

    cond do
      :fail in outcomes -> :fail
      Enum.all?(outcomes, &(&1 == :pass)) -> :pass
      Enum.all?(outcomes, &(&1 == :unsupported)) -> :unsupported
      true -> :unknown
    end
  end
end
