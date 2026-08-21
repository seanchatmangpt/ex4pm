defmodule Ex4pm.Engine.Differential do
  @moduledoc "Cross-engine semantic equivalence verifier."

  alias Ex4pm.Core.Hash
  alias Ex4pm.Engine.Registry
  alias Ex4pm.Refusal

  def compare(operation, subject, left_engine, right_engine, opts \\ []) do
    with {:ok, left_module} <- select_exact(operation, left_engine, opts),
         {:ok, right_module} <- select_exact(operation, right_engine, opts),
         {:ok, left} <-
           left_module.execute(operation, subject, Keyword.put(opts, :engine, left_engine)),
         {:ok, right} <-
           right_module.execute(operation, subject, Keyword.put(opts, :engine, right_engine)) do
      left_hash = Hash.digest(left.value)
      right_hash = Hash.digest(right.value)

      if left_hash == right_hash do
        {:ok, %{equivalent: true, hash: left_hash, left: left, right: right, standing: :alive}}
      else
        {:error,
         Refusal.new(:engine_divergence, "engine results are not semantically identical",
           details: %{
             left_engine: left_engine,
             right_engine: right_engine,
             left_hash: left_hash,
             right_hash: right_hash
           }
         )}
      end
    end
  end

  defp select_exact(operation, engine, opts) do
    Registry.select(operation, Keyword.put(opts, :engine, engine))
  end
end

defmodule Ex4pm.Engine.ExplorerProjection do
  @moduledoc "Columnar analytical projection of canonical events."

  alias Ex4pm.EventLog

  def dataframe(%EventLog{} = log) do
    data = %{
      "event_id" => Enum.map(log.events, & &1.id),
      "activity" => Enum.map(log.events, & &1.activity),
      "timestamp" => Enum.map(log.events, & &1.timestamp),
      "object_ids" => Enum.map(log.events, &Enum.join(&1.object_ids, ","))
    }

    {:ok, Explorer.DataFrame.new(data)}
  rescue
    error ->
      {:error,
       Ex4pm.Refusal.new(:explorer_projection_failed, "Explorer projection failed",
         details: %{error: Exception.message(error)}
       )}
  end
end
