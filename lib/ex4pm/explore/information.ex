defmodule Ex4pm.Explore.Information do
  @moduledoc false

  def entropy(probabilities) do
    probabilities
    |> Enum.reject(&(&1 <= 0.0))
    |> Enum.reduce(0.0, fn p, acc -> acc - p * (:math.log(p) / :math.log(2.0)) end)
  end

  def information_gain(prior, partitions) do
    total = Enum.reduce(partitions, 0, fn {_weight, samples}, acc -> acc + samples end)
    posterior = Enum.reduce(partitions, 0.0, fn {entropy, samples}, acc -> acc + entropy * samples / total end)
    prior - posterior
  end
end
