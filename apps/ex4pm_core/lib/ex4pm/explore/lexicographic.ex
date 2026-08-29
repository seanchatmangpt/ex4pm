defmodule Ex4pm.Explore.Lexicographic do
  @moduledoc false
  def rank(items, priorities, score_fun) do
    Enum.sort(items, fn a, b -> compare(score_fun.(a), score_fun.(b), priorities) != :lt end)
  end

  defp compare(_, _, []), do: :eq
  defp compare(a, b, [k | rest]) do
    av = Map.get(a, k, 0)
    bv = Map.get(b, k, 0)
    cond do
      av > bv -> :gt
      av < bv -> :lt
      true -> compare(a, b, rest)
    end
  end
end
