defmodule Ex4pm.Explore.Maximin do
  @moduledoc false
  def best(items, score_fun) do
    Enum.max_by(items, fn item -> score_fun.(item) |> Map.values() |> Enum.min(fn -> 0 end) end, fn -> nil end)
  end
end
