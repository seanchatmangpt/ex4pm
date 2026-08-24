defmodule Ex4pm.Develop.Search.Budget do
  @moduledoc false
  defstruct [:max_expansions, :max_cost, :max_depth]
  def admit(%__MODULE__{max_expansions: e, max_cost: c, max_depth: d}) when is_integer(e) and e > 0 and is_number(c) and c >= 0 and is_integer(d) and d >= 0, do: :ok
  def admit(_), do: {:error, :invalid_search_budget}
end
