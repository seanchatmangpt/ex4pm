defmodule Ex4pm.Explore.TemporalLogic do
  @moduledoc false

  def always(trace, predicate) when is_list(trace) and is_function(predicate, 1), do: Enum.all?(trace, predicate)
  def eventually(trace, predicate) when is_list(trace) and is_function(predicate, 1), do: Enum.any?(trace, predicate)

  def until(trace, hold, release) do
    Enum.reduce_while(trace, false, fn state, _ ->
      cond do
        release.(state) -> {:halt, true}
        hold.(state) -> {:cont, false}
        true -> {:halt, false}
      end
    end)
  end
end
