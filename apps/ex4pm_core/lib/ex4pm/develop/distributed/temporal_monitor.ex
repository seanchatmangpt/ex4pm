defmodule Ex4pm.Develop.Distributed.TemporalMonitor do
  @moduledoc false
  def eventually?(events, predicate, bound) when is_integer(bound) and bound >= 0 do
    events |> Enum.take(bound + 1) |> Enum.any?(predicate)
  end
  def always?(events, predicate, bound) when is_integer(bound) and bound >= 0 do
    events |> Enum.take(bound + 1) |> Enum.all?(predicate)
  end
end
