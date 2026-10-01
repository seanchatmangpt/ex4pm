defmodule Explore.BeamSearch do
  def solve(start, goal, expand, score, width), do: loop([{start,[start]}],goal,expand,score,width,0,20)
  defp loop(frontier,goal,expand,score,width,depth,limit) do
    case Enum.find(frontier,fn {n,_}->n==goal end) do
      {_,path}-> {:ok,path,depth}
      nil when depth>=limit -> :cutoff
      nil ->
        next=frontier |> Enum.flat_map(fn {n,p}->for x<-expand.(n), do:{x,p++[x]} end) |> Enum.sort_by(fn {n,_}->score.(n) end) |> Enum.take(width)
        if next==[], do: :no_path, else: loop(next,goal,expand,score,width,depth+1,limit)
    end
  end
end
expand=fn :a->[:b,:c]; :b->[:d]; :c->[:e]; :e->[:d]; _->[] end
score=fn :d->0; :b->1; :e->1; :c->2; _->3 end
{:ok,[:a,:b,:d],2}=Explore.BeamSearch.solve(:a,:d,expand,score,1)
IO.inspect(%{candidate: :beam_search, standing: :alive, width: 1})
