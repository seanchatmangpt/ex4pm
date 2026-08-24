defmodule Ex4pm.Develop.Search.RolloutConsensus do
  @moduledoc false
  def choose(votes) do
    votes
    |> Enum.frequencies()
    |> Enum.max_by(fn {candidate, count} -> {count, inspect(candidate)} end, fn -> {nil, 0} end)
    |> elem(0)
  end
end
