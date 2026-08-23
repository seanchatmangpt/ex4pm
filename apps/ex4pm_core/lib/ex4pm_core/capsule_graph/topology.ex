defmodule Ex4pmCore.CapsuleGraph.Topology do
  @moduledoc false

  def available(candidate_ids, blocked_ids) when is_list(candidate_ids) and is_list(blocked_ids) do
    blocked = MapSet.new(blocked_ids)
    remaining = candidate_ids |> Enum.uniq() |> Enum.reject(&MapSet.member?(blocked, &1)) |> Enum.sort()

    case remaining do
      [] -> {:error, {:blocked, :all_capsule_edges_unavailable}}
      _ -> {:ok, remaining}
    end
  end
end
