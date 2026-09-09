defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Selector do
  @moduledoc false

  @rank %{alive: 3, partial_alive: 2, unknown: 1, unsupported: 0, blocked: 0, build_broken: 0}

  def select(candidates) when is_list(candidates) do
    viable =
      Enum.filter(candidates, fn candidate -> Map.get(@rank, candidate.standing, -1) > 0 end)

    case Enum.sort_by(viable, fn candidate ->
           {-Map.fetch!(@rank, candidate.standing), candidate.name}
         end) do
      [selected | _] -> {:ok, selected, Enum.map(viable, & &1.name) |> Enum.sort()}
      [] -> {:error, {:refused, :no_viable_extractor}}
    end
  end
end
