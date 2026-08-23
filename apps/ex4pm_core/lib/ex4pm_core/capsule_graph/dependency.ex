defmodule Ex4pmCore.CapsuleGraph.Dependency do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.Subject

  def order(subjects, edges) when is_list(subjects) and is_list(edges) do
    keys = Map.new(subjects, &{key(&1), &1})

    with :ok <- validate_edges(keys, edges) do
      topo(keys, edges, [])
    end
  end

  defp validate_edges(keys, edges) do
    if Enum.all?(edges, fn {%Subject{} = from, %Subject{} = to} ->
         Map.has_key?(keys, key(from)) and Map.has_key?(keys, key(to)) and not Subject.same?(from, to)
       end) do
      :ok
    else
      {:error, {:refused, :invalid_dependency_edge}}
    end
  end

  defp topo(keys, [], acc), do: {:ok, Enum.reverse(acc) ++ Map.values(keys) |> Enum.uniq()}

  defp topo(keys, edges, acc) do
    incoming = MapSet.new(Enum.map(edges, fn {_, to} -> key(to) end))
    roots = keys |> Map.keys() |> Enum.reject(&MapSet.member?(incoming, &1)) |> Enum.sort()

    case roots do
      [] -> {:error, {:refused, :capsule_dependency_cycle}}
      [root | _] ->
        subject = Map.fetch!(keys, root)
        next_keys = Map.delete(keys, root)
        next_edges = Enum.reject(edges, fn {from, _} -> key(from) == root end)
        topo(next_keys, next_edges, [subject | acc])
    end
  end

  defp key(%Subject{repository: repo, sha: sha}), do: {repo, sha}
end
