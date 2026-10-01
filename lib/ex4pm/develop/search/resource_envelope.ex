defmodule Ex4pm.Develop.Search.ResourceEnvelope do
  @moduledoc false
  def within?(%{expansions: e, cost: c, depth: d}, %{max_expansions: me, max_cost: mc, max_depth: md}) do
    e <= me and c <= mc and d <= md
  end
  def within?(_, _), do: false
end
