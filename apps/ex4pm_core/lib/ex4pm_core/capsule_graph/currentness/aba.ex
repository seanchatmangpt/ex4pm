defmodule Ex4pmCore.CapsuleGraph.Currentness.ABA do
  @moduledoc false

  def detect(contexts) when is_list(contexts) do
    contexts
    |> Enum.reduce_while(%{}, fn ctx, seen ->
      case Map.get(seen, ctx.cut_id) do
        nil -> {:cont, Map.put(seen, ctx.cut_id, ctx.generation)}
        generation when generation == ctx.generation -> {:cont, seen}
        generation -> {:halt, {:error, {:refused, :aba_context, %{cut_id: ctx.cut_id, before: generation, after: ctx.generation}}}}
      end
    end)
    |> case do
      {:error, _} = error -> error
      _ -> :ok
    end
  end
end
