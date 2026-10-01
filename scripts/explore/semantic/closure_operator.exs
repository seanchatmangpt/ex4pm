defmodule Explore.ClosureOperator do
  def close(set,implications) do
    next=Enum.reduce(implications,set,fn {premise,conclusion},acc->if MapSet.subset?(premise,acc), do: MapSet.union(acc,conclusion), else: acc end)
    if next==set, do: set, else: close(next,implications)
  end
end
rules=[{MapSet.new([:a]),MapSet.new([:b])},{MapSet.new([:b]),MapSet.new([:c])}]
c=Explore.ClosureOperator.close(MapSet.new([:a]),rules)
true=c==MapSet.new([:a,:b,:c]); true=Explore.ClosureOperator.close(c,rules)==c
IO.inspect(%{candidate: :closure_operator, standing: :alive, laws: [:extensive,:idempotent]})
