defmodule Ex4pm.Explore.DataflowLattice do
  @moduledoc false

  def join(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, a, b -> join_value(a, b) end)
  end

  def monotone?(prior, later) when is_map(prior) and is_map(later) do
    Enum.all?(prior, fn {key, value} -> Map.has_key?(later, key) and subset?(value, Map.fetch!(later, key)) end)
  end

  defp join_value(%MapSet{} = a, %MapSet{} = b), do: MapSet.union(a, b)
  defp join_value(a, b) when is_list(a) and is_list(b), do: Enum.uniq(a ++ b)
  defp join_value(a, a), do: a
  defp join_value(a, b), do: MapSet.new([a, b])

  defp subset?(%MapSet{} = a, %MapSet{} = b), do: MapSet.subset?(a, b)
  defp subset?(a, b) when is_list(a) and is_list(b), do: Enum.all?(a, &(&1 in b))
  defp subset?(a, a), do: true
  defp subset?(_, _), do: false
end
