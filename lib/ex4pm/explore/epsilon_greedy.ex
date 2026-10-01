defmodule Ex4pm.Explore.EpsilonGreedy do
  @moduledoc false
  def choose(arms, epsilon, sample) when epsilon >= 0 and epsilon <= 1 do
    if sample < epsilon do
      arms |> Enum.sort_by(&elem(&1, 0)) |> List.first()
    else
      Enum.max_by(arms, &elem(&1, 1), fn -> nil end)
    end
  end
end
