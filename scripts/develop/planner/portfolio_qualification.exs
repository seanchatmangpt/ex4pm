defmodule Ex4pm.Develop.Planner.PortfolioQualification do
  @moduledoc false
  def qualify(candidates, required_ids) do
    ids = MapSet.new(Enum.map(candidates, & &1.id))
    missing = MapSet.difference(MapSet.new(required_ids), ids)
    hard = Enum.any?(candidates, &(&1.standing in [:build_broken, :blocked]))
    cond do
      hard -> {:build_broken, MapSet.to_list(missing)}
      MapSet.size(missing) > 0 -> {:unknown, MapSet.to_list(missing)}
      true -> {:partial_alive, []}
    end
  end
end
