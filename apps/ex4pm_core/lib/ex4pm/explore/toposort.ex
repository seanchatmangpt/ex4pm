defmodule Ex4pm.Explore.Toposort do
  @moduledoc false
  def sort(nodes, edges) do
    incoming = Enum.reduce(edges, Map.new(nodes, &{&1, 0}), fn {_a, b}, m -> Map.update!(m, b, &(&1 + 1)) end)
    walk(Enum.filter(nodes, &(Map.fetch!(incoming, &1) == 0)) |> Enum.sort(), edges, incoming, [])
  end

  defp walk([], _edges, incoming, acc) do
    if Enum.all?(incoming, fn {_k, v} -> v == 0 end), do: {:ok, Enum.reverse(acc)}, else: {:error, :cycle}
  end
  defp walk([n | rest], edges, incoming, acc) do
    {incoming, newly_zero} = edges |> Enum.filter(&(elem(&1, 0) == n)) |> Enum.reduce({incoming, []}, fn {_a, b}, {m, z} ->
      m = Map.update!(m, b, &(&1 - 1)); if Map.fetch!(m, b) == 0, do: {m, [b | z]}, else: {m, z}
    end)
    walk(Enum.sort(rest ++ newly_zero), edges, Map.put(incoming, n, 0), [n | acc])
  end
end
