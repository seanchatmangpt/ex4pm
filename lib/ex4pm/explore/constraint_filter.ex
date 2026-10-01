defmodule Ex4pm.Explore.ConstraintFilter do
  @moduledoc false
  def admit(items, predicates) do
    Enum.split_with(items, fn item -> Enum.all?(predicates, & &1.(item)) end)
  end
end
