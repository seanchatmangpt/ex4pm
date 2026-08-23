defmodule Ex4pm.Explore.RobustInterval do
  @moduledoc false

  def add({alo, ahi}, {blo, bhi}), do: {alo + blo, ahi + bhi}
  def scale({lo, hi}, factor) when factor >= 0, do: {lo * factor, hi * factor}
  def scale({lo, hi}, factor), do: {hi * factor, lo * factor}
  def contains?({lo, hi}, value), do: value >= lo and value <= hi

  def robust?(interval, constraint) when is_function(constraint, 1) do
    {lo, hi} = interval
    constraint.(lo) and constraint.(hi)
  end
end
