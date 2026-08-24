defmodule Explore.Kleene do
  def fix(seed, step) do
    next = step.(seed)
    if next == seed, do: seed, else: fix(next, step)
  end
end
step = fn s -> s |> MapSet.put(:a) |> then(fn x -> if MapSet.member?(x,:a), do: MapSet.put(x,:b), else: x end) end
result=Explore.Kleene.fix(MapSet.new(),step)
true = result == MapSet.new([:a,:b])
IO.inspect(%{candidate: :kleene_fixed_point, standing: :alive, result: Enum.sort(result)})
