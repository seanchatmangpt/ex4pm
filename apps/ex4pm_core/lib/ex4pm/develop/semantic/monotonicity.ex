defmodule Ex4pm.Develop.Semantic.Monotonicity do
  @moduledoc false
  def monotone?(ordered_pairs, f, leq) do
    Enum.all?(ordered_pairs, fn {a,b} -> not leq.(a,b) or leq.(f.(a), f.(b)) end)
  end
end
