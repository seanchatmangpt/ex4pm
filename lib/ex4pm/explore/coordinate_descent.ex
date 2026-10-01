defmodule Ex4pm.Explore.CoordinateDescent do
  @moduledoc false

  def optimize(point, objective, step, iterations) when is_map(point) and iterations >= 0 do
    Enum.reduce(1..max(iterations, 1), point, fn _, current ->
      if iterations == 0, do: current, else: sweep(current, objective, step)
    end)
  end

  defp sweep(point, objective, step) do
    Enum.reduce(Map.keys(point), point, fn key, current ->
      value = Map.fetch!(current, key)
      candidates = [Map.put(current, key, value - step), current, Map.put(current, key, value + step)]
      Enum.min_by(candidates, objective)
    end)
  end
end
