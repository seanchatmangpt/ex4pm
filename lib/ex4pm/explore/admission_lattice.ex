defmodule Ex4pm.Explore.AdmissionLattice do
  @moduledoc false
  @rank %{UNKNOWN: 0, BLOCKED: 1, UNSUPPORTED: 1, BUILD_BROKEN: 1, REFUSED: 1, PARTIAL_ALIVE: 2, ALIVE: 3}

  def join(a, b) when is_map_key(@rank, a) and is_map_key(@rank, b) do
    cond do
      a == :ALIVE or b == :ALIVE -> :ALIVE
      a == :PARTIAL_ALIVE or b == :PARTIAL_ALIVE -> :PARTIAL_ALIVE
      a == b -> a
      true -> :UNKNOWN
    end
  end

  def dominates?(a, b) when is_map_key(@rank, a) and is_map_key(@rank, b), do: @rank[a] > @rank[b]
  def valid?(status), do: is_map_key(@rank, status)
end
