defmodule Ex4pmCore.CapsuleGraph.Currentness.Frontier do
  @moduledoc false

  def build(attempts) when is_list(attempts) and attempts != [] do
    max_ordinal = attempts |> Enum.map(& &1.ordinal) |> Enum.max()
    current = Enum.filter(attempts, &(&1.ordinal == max_ordinal))

    case current do
      [attempt] ->
        {:ok, %{current: attempt, historical: Enum.reject(attempts, &(&1.id == attempt.id))}}

      _ ->
        {:error, {:refused, :divergent_attempt_frontier}}
    end
  end

  def build(_), do: {:error, {:refused, :empty_attempt_frontier}}
end
