defmodule Explore.BFS do
  def solve(start, goal, edges) do
    walk(:queue.from_list([{start, [start]}]), MapSet.new([start]), goal, edges)
  end
  defp walk(q, seen, goal, edges) do
    case :queue.out(q) do
      {{:value, {^goal, path}}, _} -> {:ok, path}
      {{:value, {node, path}}, q2} ->
        next = for {^node, to} <- edges, not MapSet.member?(seen, to), do: to
        walk(Enum.reduce(next, q2, &:queue.in({&1, path ++ [&1]}, &2)), Enum.reduce(next, seen, &MapSet.put(&2, &1)), goal, edges)
      {:empty, _} -> :no_path
    end
  end
end
edges=[{:a,:b},{:a,:c},{:b,:d},{:c,:e},{:e,:d}]
{:ok, path}=Explore.BFS.solve(:a,:d,edges)
true = path == [:a,:b,:d]
IO.inspect(%{candidate: :bfs, standing: :alive, path: path})
