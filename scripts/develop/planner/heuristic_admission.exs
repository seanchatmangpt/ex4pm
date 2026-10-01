defmodule Ex4pm.Develop.Planner.HeuristicAdmission do
  @moduledoc false
  def consistent?(edges, h) do
    Enum.all?(edges, fn {u, v, cost} -> Map.fetch!(h, u) <= cost + Map.fetch!(h, v) end)
  end
  def admit(edges, h), do: if(consistent?(edges, h), do: :ok, else: {:refused, :inconsistent_heuristic})
end
