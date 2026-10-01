defmodule Ex4pm.Develop.Semantic.FixedPointCertificate do
  @moduledoc false
  def iterate(seed, step, leq?, limit) when limit > 0 do
    Enum.reduce_while(1..limit, seed, fn _, current ->
      next = step.(current)
      cond do
        next == current -> {:halt, {:ok, %{fixed: next}}}
        not leq?.(current, next) -> {:halt, {:refused, :non_monotone_step}}
        true -> {:cont, next}
      end
    end)
    |> case do
      {:ok, _} = ok -> ok
      {:refused, _} = refused -> refused
      _ -> {:refused, :fixed_point_bound_exhausted}
    end
  end
end
