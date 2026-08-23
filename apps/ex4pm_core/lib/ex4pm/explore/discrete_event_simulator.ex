defmodule Ex4pm.Explore.DiscreteEventSimulator do
  @moduledoc false

  def run(initial, events, handler) when is_function(handler, 2) do
    events
    |> Enum.sort_by(&Map.fetch!(&1, :at))
    |> Enum.reduce({initial, []}, fn event, {state, history} ->
      next = handler.(state, event)
      {next, history ++ [{event, next}]}
    end)
  end
end
