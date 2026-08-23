defmodule Ex4pmCore.CapsuleGraph.Independence.Frontier do
  @moduledoc false

  def build(witnesses, attempt_id, now) when is_list(witnesses) and is_binary(attempt_id) do
    with :ok <- unique_evidence(witnesses),
         :ok <- nonfuture(witnesses, now) do
      {current, historical} = Enum.split_with(witnesses, &(&1.attempt_id == attempt_id))
      {:ok, %{current: current, historical: historical}}
    end
  end

  def build(_, _, _), do: {:error, {:refused, :invalid_evidence_frontier}}

  defp unique_evidence(witnesses) do
    ids = Enum.map(witnesses, & &1.evidence_id)

    if length(ids) == MapSet.size(MapSet.new(ids)),
      do: :ok,
      else: {:error, {:refused, :duplicate_evidence_id}}
  end

  defp nonfuture(witnesses, %DateTime{} = now) do
    if Enum.any?(witnesses, &(DateTime.compare(&1.observed_at, now) == :gt)) do
      {:error, {:refused, :future_evidence}}
    else
      :ok
    end
  end

  defp nonfuture(_, _), do: {:error, {:refused, :invalid_observation_clock}}
end
