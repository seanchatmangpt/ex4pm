defmodule Explore.AStar do
  def solve(start, goal, edges, h), do: loop([{h.(start), 0, start, [start]}], MapSet.new(), goal, edges, h)
  defp loop([{_, g, goal, path} | _], _, goal, _, _), do: {:ok, g, path}
  defp loop([{_, g, node, path} | rest], seen, goal, edges, h) do
    if MapSet.member?(seen, node) do
      loop(rest, seen, goal, edges, h)
    else
      expanded = for {^node, to, w} <- edges, do: {g + w + h.(to), g + w, to, path ++ [to]}
      loop(Enum.sort(expanded ++ rest), MapSet.put(seen, node), goal, edges, h)
    end
  end
end
h = fn :a -> 2; :b -> 1; :d -> 0 end
{:ok, 2, [:a, :b, :d]} = Explore.AStar.solve(:a, :d, [{:a, :d, 9}, {:a, :b, 1}, {:b, :d, 1}], h)
IO.inspect(%{candidate: :astar, standing: :alive})
