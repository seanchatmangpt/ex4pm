defmodule Ex4pm.Explore.TokenReplay do
  @moduledoc false

  def replay(trace, transitions, initial) do
    Enum.reduce_while(trace, {:ok, initial, []}, fn activity, {:ok, marking, history} ->
      case Map.get(transitions, {marking, activity}) do
        nil -> {:halt, {:error, {:nonconformant, activity, marking, Enum.reverse(history)}}}
        next -> {:cont, {:ok, next, [activity | history]}}
      end
    end)
    |> normalize()
  end

  defp normalize({:ok, marking, history}), do: {:ok, marking, Enum.reverse(history)}
  defp normalize(error), do: error
end
