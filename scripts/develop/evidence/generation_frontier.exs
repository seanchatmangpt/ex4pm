defmodule Ex4pm.Develop.Evidence.GenerationFrontier do
  def current(evidence) do
    generation = evidence |> Enum.map(& &1.generation) |> Enum.max()
    latest = Enum.filter(evidence, &(&1.generation == generation))
    digests = MapSet.new(Enum.map(latest, & &1.digest))
    if MapSet.size(digests) == 1, do: {:ok, hd(latest)}, else: {:refused, :split_current_evidence}
  end
end
