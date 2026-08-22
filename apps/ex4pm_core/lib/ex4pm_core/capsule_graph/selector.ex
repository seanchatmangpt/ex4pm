defmodule Ex4pmCore.CapsuleGraph.Selector do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.{Admission, Candidate, Compatibility, Evidence}

  def select(candidates, required) when is_list(candidates) and is_list(required) do
    viable =
      candidates
      |> Enum.flat_map(fn %Candidate{} = candidate ->
        with {:ok, admitted} <- Admission.admit(candidate),
             {:ok, :compatible} <- Compatibility.verify(admitted.capabilities, required) do
          [{rank(admitted), admitted}]
        else
          _ -> []
        end
      end)
      |> Enum.sort_by(fn {rank, candidate} -> {-rank, candidate.id} end)

    case viable do
      [{_, selected} | _] ->
        {:ok, selected, viable |> Enum.map(fn {_, candidate} -> candidate.id end) |> Enum.sort()}

      [] ->
        {:error, {:refused, :no_viable_capsule}}
    end
  end

  defp rank(candidate) do
    case Evidence.standing(candidate.evidence) do
      :partial_alive -> length(candidate.evidence)
      _ -> 0
    end
  end
end
