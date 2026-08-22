defmodule Ex4pm.Information.Interop do
  @moduledoc """
  Canonical JSON interchange projections for process-intelligence values.

  Internal Elixir map keys and tuple DFG edges are never leaked as an accidental
  wire format. This projection is shared by CLI, JSONL, wasm4pm, and pm4py
  clients.
  """

  alias Ex4pm.Information.Protocol
  alias Ex4pm.Refusal

  def encode_model(%{type: :dfg} = model) do
    %{
      "type" => "dfg",
      "object_type" => Map.get(model, :object_type),
      "activities" => string_key_map(Map.get(model, :activities, %{})),
      "edges" =>
        model
        |> Map.get(:edges, %{})
        |> Enum.map(fn {{source, target}, stats} ->
          %{
            "source" => source,
            "target" => target,
            "count" => value(stats, :count, 0),
            "average_duration_ms" => value(stats, :average_duration_ms)
          }
        end)
        |> Enum.sort_by(&{&1["source"], &1["target"]}),
      "starts" => string_key_map(Map.get(model, :starts, %{})),
      "ends" => string_key_map(Map.get(model, :ends, %{})),
      "trace_count" => Map.get(model, :trace_count, 0)
    }
  end

  def encode_model(%{type: :variants} = model) do
    variants =
      model
      |> Map.get(:variants, %{})
      |> Enum.map(fn {path, count} -> %{"path" => path, "count" => count} end)
      |> Enum.sort_by(& &1["path"])

    %{
      "type" => "variants",
      "variants" => variants,
      "trace_count" => Map.get(model, :trace_count, 0)
    }
  end

  def encode_model(model) when is_map(model), do: Protocol.json_safe(model)
  def encode_model(other), do: other

  def decode_model(model) when is_map(model) do
    case value(model, "type") do
      "dfg" -> decode_dfg(model)
      :dfg -> decode_dfg(model)

      other ->
        {:error,
         Refusal.new(:unsupported_interchange_model, "only DFG interchange models are admitted",
           details: %{type: other}
         )}
    end
  end

  def decode_model(other) do
    {:error,
     Refusal.new(:invalid_interchange_model, "model must be a JSON object", subject: other)}
  end

  def event_log_summary(%Ex4pm.EventLog{} = log) do
    %{
      "kind" => "event_log",
      "subject_hash" => log.subject.hash,
      "events" => length(log.events),
      "objects" => map_size(log.objects),
      "object_relationships" => length(log.object_relationships),
      "metadata" => Protocol.json_safe(log.metadata)
    }
  end

  def event_log_summary(other), do: Protocol.json_safe(other)

  def run_value(%Ex4pm.Run{operation: :discover, value: value}), do: encode_model(value)
  def run_value(%Ex4pm.Run{value: value}), do: Protocol.json_safe(value)

  def underlying_receipts(%Ex4pm.Run{receipt: %{hash: hash}}), do: [hash]
  def underlying_receipts(_), do: []

  def run_provenance(%Ex4pm.Run{} = run) do
    %{
      operation: run.operation,
      subject_hash: run.subject_hash,
      engine: run.engine_result && run.engine_result.engine,
      algorithm: run.engine_result && run.engine_result.algorithm,
      engine_evidence: run.engine_result && Protocol.json_safe(run.engine_result.evidence)
    }
  end

  defp decode_dfg(model) do
    with {:ok, activities} <- count_map(value(model, "activities", %{}), "activities"),
         {:ok, starts} <- count_map(value(model, "starts", %{}), "starts"),
         {:ok, ends} <- count_map(value(model, "ends", %{}), "ends"),
         {:ok, edges} <- decode_edges(value(model, "edges", [])),
         {:ok, trace_count} <- non_negative_integer(value(model, "trace_count", 0), "trace_count") do
      {:ok,
       %{
         type: :dfg,
         object_type: value(model, "object_type"),
         activities: activities,
         edges: edges,
         starts: starts,
         ends: ends,
         trace_count: trace_count
       }}
    end
  end

  defp decode_edges(edges) when is_list(edges) do
    edges
    |> Enum.reduce_while({:ok, %{}}, fn edge, {:ok, acc} ->
      with true <- is_map(edge),
           source when is_binary(source) <- value(edge, "source"),
           target when is_binary(target) <- value(edge, "target"),
           {:ok, count} <- non_negative_integer(value(edge, "count", 0), "edge.count"),
           {:ok, average} <- optional_number(value(edge, "average_duration_ms")) do
        stats = %{count: count, average_duration_ms: average}
        {:cont, {:ok, Map.put(acc, {source, target}, stats)}}
      else
        _ ->
          {:halt,
           {:error, Refusal.new(:invalid_interchange_edge, "DFG edge is malformed", subject: edge)}}
      end
    end)
  end

  defp decode_edges(other) do
    {:error, Refusal.new(:invalid_interchange_edges, "DFG edges must be an array", subject: other)}
  end

  defp count_map(map, field) when is_map(map) do
    map
    |> Enum.reduce_while({:ok, %{}}, fn {key, count}, {:ok, acc} ->
      with true <- is_binary(key),
           {:ok, count} <- non_negative_integer(count, field) do
        {:cont, {:ok, Map.put(acc, key, count)}}
      else
        _ ->
          {:halt,
           {:error,
            Refusal.new(:invalid_interchange_counts, "#{field} must map strings to counts",
              subject: map
            )}}
      end
    end)
  end

  defp count_map(other, field) do
    {:error, Refusal.new(:invalid_interchange_counts, "#{field} must be an object", subject: other)}
  end

  defp non_negative_integer(value, _field) when is_integer(value) and value >= 0, do: {:ok, value}

  defp non_negative_integer(value, field) do
    {:error,
     Refusal.new(:invalid_interchange_integer, "#{field} must be a non-negative integer",
       subject: value
     )}
  end

  defp optional_number(nil), do: {:ok, nil}
  defp optional_number(value) when is_number(value), do: {:ok, value}

  defp optional_number(value) do
    {:error,
     Refusal.new(:invalid_interchange_number, "average_duration_ms must be numeric or null",
       subject: value
     )}
  end

  defp string_key_map(map) when is_map(map) do
    Map.new(map, fn {key, val} -> {to_string(key), val} end)
  end

  defp value(map, key, default \\ nil) when is_map(map) and is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, val} ->
        val

      :error ->
        atom =
          case key do
            "type" -> :type
            "object_type" -> :object_type
            "activities" -> :activities
            "edges" -> :edges
            "starts" -> :starts
            "ends" -> :ends
            "trace_count" -> :trace_count
            "source" -> :source
            "target" -> :target
            "count" -> :count
            "average_duration_ms" -> :average_duration_ms
            _ -> nil
          end

        if atom && Map.has_key?(map, atom), do: Map.fetch!(map, atom), else: default
    end
  end

  defp value(map, key, default) when is_map(map) and is_atom(key),
    do: Map.get(map, key, Map.get(map, Atom.to_string(key), default))
end
