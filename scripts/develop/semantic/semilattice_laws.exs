defmodule Ex4pm.Develop.Semantic.SemilatticeLaws do
  @moduledoc false
  def verify(samples, join) do
    idempotent = Enum.all?(samples, fn a -> join.(a,a) == a end)
    commutative = Enum.all?(samples, fn a -> Enum.all?(samples, fn b -> join.(a,b) == join.(b,a) end) end)
    associative = Enum.all?(samples, fn a -> Enum.all?(samples, fn b -> Enum.all?(samples, fn c -> join.(join.(a,b),c) == join.(a,join.(b,c)) end) end) end)
    if idempotent and commutative and associative, do: :ok, else: {:refused, :invalid_join_semilattice}
  end
end
