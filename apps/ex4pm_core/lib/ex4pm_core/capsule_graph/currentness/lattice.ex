defmodule Ex4pmCore.CapsuleGraph.Currentness.Lattice do
  @moduledoc false
  @rank %{unsupported: 0, unknown: 1, partial_alive: 2, alive: 3, blocked: 4, build_broken: 5}

  def join(values) when is_list(values) and values != [] do
    if Enum.any?(values, &(&1 in [:blocked, :build_broken])) do
      Enum.max_by(values, &Map.get(@rank, &1, -1))
    else
      Enum.min_by(values, &Map.get(@rank, &1, -1))
    end
  end

  def join(_), do: :unknown
end
