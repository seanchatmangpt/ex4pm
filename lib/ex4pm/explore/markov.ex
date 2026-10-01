defmodule Ex4pm.Explore.Markov do
  @moduledoc false

  def fit(transitions) do
    counts = Enum.frequencies_by(transitions, fn {from, to} -> {from, to} end)
    totals = Enum.reduce(counts, %{}, fn {{from, _to}, count}, acc -> Map.update(acc, from, count, &(&1 + count)) end)

    Map.new(counts, fn {{from, to}, count} -> {{from, to}, count / Map.fetch!(totals, from)} end)
  end

  def predict(state, matrix) do
    matrix
    |> Enum.filter(fn {{from, _to}, _p} -> from == state end)
    |> Enum.max_by(fn {_edge, p} -> p end, fn -> nil end)
    |> case do
      nil -> {:error, :unknown_state}
      {{_from, to}, probability} -> {:ok, to, probability}
    end
  end
end
