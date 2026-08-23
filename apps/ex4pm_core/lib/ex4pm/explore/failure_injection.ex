defmodule Ex4pm.Explore.FailureInjection do
  @moduledoc false

  def apply(subject, injections) when is_list(injections) do
    Enum.reduce_while(injections, {:ok, subject, []}, fn injection, {:ok, current, applied} ->
      case injection do
        %{when: predicate, transform: transform, id: id} when is_function(predicate, 1) and is_function(transform, 1) ->
          if predicate.(current), do: {:cont, {:ok, transform.(current), [id | applied]}}, else: {:cont, {:ok, current, applied}}
        invalid -> {:halt, {:error, {:invalid_injection, invalid}}}
      end
    end)
    |> case do
      {:ok, current, applied} -> {:ok, current, Enum.reverse(applied)}
      error -> error
    end
  end
end
