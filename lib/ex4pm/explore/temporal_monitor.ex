defmodule Ex4pm.Explore.TemporalMonitor do
  @moduledoc false
  def eventually?(events, predicate, horizon) when horizon >= 0 do
    events |> Enum.take(horizon) |> Enum.any?(predicate)
  end

  def always?(events, predicate, horizon) when horizon >= 0 do
    events |> Enum.take(horizon) |> Enum.all?(predicate)
  end

  def weak_until?(events, hold, release, horizon) when horizon >= 0 do
    scan_until(events |> Enum.take(horizon), hold, release, false, :weak)
  end

  def strong_until?(events, hold, release, horizon) when horizon >= 0 do
    scan_until(events |> Enum.take(horizon), hold, release, false, :strong)
  end

  def until?(events, hold, release, horizon), do: weak_until?(events, hold, release, horizon)

  defp scan_until([], _hold, _release, seen_release, :strong), do: seen_release
  defp scan_until([], _hold, _release, _seen_release, :weak), do: true
  defp scan_until([event | rest], hold, release, seen_release, mode) do
    cond do
      release.(event) -> true
      hold.(event) -> scan_until(rest, hold, release, seen_release, mode)
      true -> false
    end
  end
end
