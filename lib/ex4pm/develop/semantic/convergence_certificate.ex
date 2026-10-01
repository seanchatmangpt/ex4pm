defmodule Ex4pm.Develop.Semantic.ConvergenceCertificate do
  @moduledoc false
  def certify(values, metric, tolerance) when is_number(tolerance) and tolerance >= 0 do
    distances = values |> Enum.chunk_every(2,1,:discard) |> Enum.map(fn [a,b] -> metric.(a,b) end)
    case distances do
      [] -> {:error, :insufficient_trajectory}
      _ -> if List.last(distances) <= tolerance, do: {:ok, %{steps: length(distances), final_distance: List.last(distances)}}, else: {:error, {:not_converged, List.last(distances)}}
    end
  end
end
