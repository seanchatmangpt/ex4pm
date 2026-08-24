defmodule Ex4pm.Develop.Semantic.BisimulationWitness do
  @moduledoc false
  def verify(left, right, relation, transitions, depth) when depth >= 0 do
    walk([{left,right,0}], MapSet.new(), relation, transitions, depth)
  end
  defp walk([], seen, _relation, _transitions, _depth), do: {:ok, seen}
  defp walk([{l,r,d}|rest], seen, relation, transitions, depth) do
    pair={l,r}
    cond do
      MapSet.member?(seen,pair) -> walk(rest,seen,relation,transitions,depth)
      not relation.(l,r) -> {:refused,{:relation_failed,pair}}
      d == depth -> walk(rest,MapSet.put(seen,pair),relation,transitions,depth)
      true ->
        ln=transitions.(l); rn=transitions.(r)
        if length(ln)==length(rn), do: walk(rest ++ Enum.zip(ln,rn) |> Enum.map(fn {a,b}->{a,b,d+1} end),MapSet.put(seen,pair),relation,transitions,depth), else: {:refused,{:branching_divergence,pair}}
    end
  end
end
