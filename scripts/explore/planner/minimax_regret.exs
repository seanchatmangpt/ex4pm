defmodule Explore.MinimaxRegret do
  def select(options,scenarios) do
    ideals=Enum.map(scenarios,fn s->options|>Enum.map(fn {_,costs}->Map.fetch!(costs,s) end)|>Enum.min() end)
    options |> Enum.min_by(fn {_,costs}-> Enum.zip(scenarios,ideals)|>Enum.map(fn {s,i}->Map.fetch!(costs,s)-i end)|>Enum.max() end) |> elem(0)
  end
end
opts=[safe: %{low: 3, high: 3}, risky: %{low: 1, high: 8}, slow: %{low: 4, high: 2}]
:safe=Explore.MinimaxRegret.select(opts,[:low,:high])
IO.inspect(%{candidate: :minimax_regret, standing: :alive})
