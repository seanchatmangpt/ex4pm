defmodule Ex4pm.Qualification.Rails do
  @moduledoc "Capability-indexed differential court for canonical engine executions."

  alias Ex4pm.Core.Hash
  alias Ex4pm.Engine.Result

  @required [:beam, :ex4pm_plan, :wasm, :nif, :remote]

  def required, do: @required

  def verify(results) when is_list(results) do
    with :ok <- require_alive_reference_rails(results),
         :ok <- compare_shared_operations(results) do
      {:ok, %{standing: :alive, rails: Enum.map(results, &summary/1)}}
    end
  end

  defp require_alive_reference_rails(results) do
    observed = Map.new(results, &{&1.engine, &1.standing})
    missing = Enum.reject(@required, &(Map.get(observed, &1) == :alive))
    if missing == [], do: :ok, else: {:error, {:rails_not_alive, missing}}
  end

  defp compare_shared_operations(results) do
    results
    |> Enum.group_by(& &1.operation)
    |> Enum.reduce_while(:ok, fn {_operation, group}, :ok ->
      alive = Enum.filter(group, &(&1.standing == :alive))
      hashes = alive |> Enum.map(&canonical_hash/1) |> Enum.uniq()

      if length(alive) > 1 and length(hashes) != 1,
        do: {:halt, {:error, {:differential_mismatch, Enum.map(alive, & &1.engine)}}},
        else: {:cont, :ok}
    end)
  end

  defp canonical_hash(%Result{value: value}), do: Hash.digest(value)

  defp summary(result),
    do: %{
      engine: result.engine,
      operation: result.operation,
      standing: result.standing,
      result_hash: canonical_hash(result),
      evidence: result.evidence
    }
end
