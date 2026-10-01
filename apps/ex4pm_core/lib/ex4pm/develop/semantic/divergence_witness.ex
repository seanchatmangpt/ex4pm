defmodule Ex4pm.Develop.Semantic.DivergenceWitness do
  @moduledoc false
  def first(left, right, projection) do
    Enum.zip(left, right)
    |> Enum.with_index()
    |> Enum.find_value(fn {{a,b}, idx} -> if projection.(a) != projection.(b), do: {:diverged_at, idx, projection.(a), projection.(b)} end)
    |> case do
      nil -> if length(left) == length(right), do: :equivalent_prefix, else: {:length_divergence, length(left), length(right)}
      witness -> witness
    end
  end
end
