defmodule Explore.UCB1 do
  def select(arms,total) do
    arms |> Enum.max_by(fn {_id,{reward,n}} -> reward/n + :math.sqrt(2*:math.log(total)/n) end) |> elem(0)
  end
end
:b=Explore.UCB1.select([a: {4.0,4}, b: {3.0,1}],5)
IO.inspect(%{candidate: :ucb1, standing: :alive, selected: :b})
