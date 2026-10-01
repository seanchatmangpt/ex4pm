defmodule Ex4pm.Explore.DifferentialComparator do
  @moduledoc false

  def compare(input, implementations, canonicalizer \\ & &1) when is_map(implementations) do
    observations = Map.new(implementations, fn {id, implementation} -> {id, canonicalizer.(implementation.(input))} end)
    groups = Enum.group_by(observations, fn {_id, value} -> value end, fn {id, _value} -> id end)

    case map_size(groups) do
      0 -> {:error, :no_implementations}
      1 -> {:equivalent, observations}
      _ -> {:divergent, observations, groups}
    end
  end
end
