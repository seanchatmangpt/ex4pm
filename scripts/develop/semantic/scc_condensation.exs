defmodule Ex4pm.Develop.Semantic.SccCondensation do
  @moduledoc false
  def condense(components, edges) do
    index = components |> Enum.with_index() |> Enum.reduce(%{}, fn {nodes,i},acc -> Enum.reduce(nodes,acc,&Map.put(&2,&1,i)) end)
    dag = edges |> Enum.map(fn {a,b}->{Map.fetch!(index,a),Map.fetch!(index,b)} end) |> Enum.reject(fn {a,b}->a==b end) |> MapSet.new()
    %{components: components, edges: dag}
  end
end
