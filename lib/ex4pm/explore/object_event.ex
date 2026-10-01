defmodule Ex4pm.Explore.ObjectEvent do
  @moduledoc false

  def index(events) do
    Enum.reduce(events, %{}, fn event, acc ->
      Enum.reduce(Map.get(event, :objects, []), acc, fn object_id, index ->
        Map.update(index, object_id, [event], &(&1 ++ [event]))
      end)
    end)
  end

  def project(events, object_id), do: events |> index() |> Map.get(object_id, [])

  def event_centric(events) do
    Enum.map(events, &Map.drop(&1, [:objects]))
  end
end
