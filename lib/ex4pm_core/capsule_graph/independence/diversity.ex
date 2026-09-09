defmodule Ex4pmCore.CapsuleGraph.Independence.Diversity do
  @moduledoc false

  def effective(clusters) when is_list(clusters) and clusters != [] do
    sizes = Enum.map(clusters, &length/1)
    total = Enum.sum(sizes)
    denominator = Enum.reduce(sizes, 0, fn n, acc -> acc + n * n end)
    reduce(total * total, denominator)
  end

  def effective(_), do: {0, 1}

  defp reduce(numerator, denominator) do
    divisor = Integer.gcd(numerator, denominator)
    {div(numerator, divisor), div(denominator, divisor)}
  end
end
