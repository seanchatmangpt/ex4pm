defmodule Ex4pm.Develop.Semantic.Law do
  @moduledoc false
  def semilattice?(values, join) do
    Enum.all?(values, fn a ->
      join.(a, a) == a and
        Enum.all?(values, fn b ->
          join.(a, b) == join.(b, a) and
            Enum.all?(values, fn c -> join.(join.(a, b), c) == join.(a, join.(b, c)) end)
        end)
    end)
  end
end
