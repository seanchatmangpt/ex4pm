defmodule Ex4pmCore.CapsuleGraph.Independence.Clusters do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Independence.Relation

  def build(sources, provenance, independent_pairs \\ MapSet.new()) when is_list(sources) do
    Enum.reduce(sources, [], fn source, clusters -> insert(source, clusters, provenance, independent_pairs) end)
    |> Enum.map(&Enum.sort_by(&1, fn source -> source.id end))
    |> Enum.sort_by(fn cluster -> hd(cluster).id end)
  end

  defp insert(source, [], _, _), do: [[source]]

  defp insert(source, clusters, provenance, independent_pairs) do
    {related, separate} =
      Enum.split_with(clusters, fn cluster ->
        Enum.any?(cluster, fn member ->
          Relation.classify(source, member, provenance, independent_pairs) in [:same_evidence, :correlated]
        end)
      end)

    case related do
      [] -> [[source] | separate]
      _ -> [[source | Enum.flat_map(related, & &1)] | separate]
    end
  end
end
