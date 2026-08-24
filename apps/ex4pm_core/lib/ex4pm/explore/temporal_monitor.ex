defmodule Ex4pm.Explore.TemporalMonitor do
  @moduledoc false
  def eventually?(events, predicate, horizon) when horizon >= 0 do
    events |> Enum.take(horizon) |> Enum.any?(predicate)
  end

  def always?(events, predicate, horizon) when horizon >= 0 do
    events |> Enum.take(horizon) |> Enum.all?(predicate)
  end

  def until?(events, hold, release, horizon) when horizon >= 0 do
    events
    |> Enum.take(horizon)
    |> Enum.reduce_while(true, fn event, _ ->
      cond do
        release.(event) -> {:halt, true}
        hold.(event) -> {:cont, true}
        true -> {:halt, false}
      end
    end)
  end
end
