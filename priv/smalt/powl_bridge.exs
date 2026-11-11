# Smalt OCEL -> ex4pm file-level bridge (zero smalt deps in ex4pm, zero ex4pm
# deps in smalt). Smalt assembles its OCEL 2.0 NDJSON via
# Smalt.Telemetry.OcelNdjson.assemble_document/1 and maps it to the
# Ex4pm.ingest/1 shape (type->activity, time->timestamp, relationships ->
# object_ids); this script does the process mining:
#
#   elixir -S mix run priv/smalt/powl_bridge.exs discover <in.json> <out.json> <object_type>
#   elixir -s mix run priv/smalt/powl_bridge.exs conform  <in.json> <model.json> <out.json> <object_type>
#
# discover: ingest -> flatten per object-type -> Ex4pm.discover/2 (DFG golden
# path) -> JSON-serializable model + receipted-run standing.
# conform: rebuild the DFG (tuple edges) -> Ex4pm.conform/3 -> fitness report.

alias Ex4pm.EventLog

defmodule SmaltBridge do
  def ingest(path) do
    case path |> File.read!() |> Jason.decode!() |> Ex4pm.ingest() do
      {:ok, %EventLog{} = log} -> {:ok, log}
      {:error, refusal} -> {:error, Map.get(refusal, :code) || inspect(refusal)}
    end
  end

  @doc "Flattens per object-type: %{type => %{traces: n, activities: [...]}}"
  def flatten_per_type(%EventLog{} = log) do
    types =
      log.objects |> Map.values() |> Enum.map(&to_string(&1.type)) |> Enum.uniq() |> Enum.sort()

    for t <- types, into: %{} do
      case Ex4pm.OCEL.flatten(log, t) do
        {:ok, traces} ->
          acts =
            traces |> Map.values() |> List.flatten() |> Enum.map(& &1.activity) |> Enum.frequencies()

          {t, %{traces: map_size(traces), activity_frequencies: acts}}

        {:error, _} ->
          {t, %{traces: 0, activity_frequencies: %{}}}
      end
    end
  end

  @doc "JSON-safe DFG serialization: tuple edges become %{from,to,...} rows."
  def encode_model(%{} = dfg) do
    %{
      "type" => "dfg",
      "object_type" => dfg.object_type,
      "activities" => dfg.activities,
      "trace_count" => dfg.trace_count,
      "starts" => Map.new(dfg.starts, fn {k, v} -> {to_string(k), v} end),
      "ends" => Map.new(dfg.ends, fn {k, v} -> {to_string(k), v} end),
      "edges" =>
        for({{a, b}, meta} <- Enum.sort_by(dfg.edges, fn {{a, b}, _} -> {a, b} end), do:
              %{"from" => a, "to" => b} |> Map.merge(atomic(meta)))
    }
  end

  defp atomic(%{} = m), do: Map.new(m, fn {k, v} -> {to_string(k), v} end)

  @doc "Rebuilds the engine-shaped DFG (atom keys, tuple edge keys) from JSON."
  def decode_model(json) do
    %{
      type: :dfg,
      object_type: json["object_type"],
      activities: json["activities"],
      trace_count: json["trace_count"],
      starts: Map.new(json["starts"] || %{}, fn {k, v} -> {k, v} end),
      ends: Map.new(json["ends"] || %{}, fn {k, v} -> {k, v} end),
      edges:
        Map.new(json["edges"], fn e ->
          {{e["from"], e["to"]}, %{count: e["count"], average_duration_ms: e["average_duration_ms"]}}
        end)
    }
  end

  def run_standing({:ok, %Ex4pm.Run{} = run}), do: %{standing: run.standing, receipt_hash: run.subject_hash}
  def run_standing({:error, refusal}), do: %{standing: :refused, code: Map.get(refusal, :code)}
end

case System.argv() do
  ["discover", in_path, out_path, object_type] ->
    with {:ok, log} <- SmaltBridge.ingest(in_path),
         {:ok, traces} <- Ex4pm.OCEL.flatten(log, object_type) do
      per_type = SmaltBridge.flatten_per_type(log)

      case Ex4pm.discover(log, object_type: object_type) do
        {:ok, %Ex4pm.Run{} = run} ->
          out = %{
            "object_type" => object_type,
            "model" => SmaltBridge.encode_model(run.value),
            "standing" => to_string(run.standing),
            "subject_hash" => run.subject_hash,
            "per_object_type" => per_type,
            "traces" => map_size(traces)
          }

          File.write!(out_path, Jason.encode!(out, pretty: true))
          IO.puts("discover ok: #{map_size(traces)} traces for #{object_type}, standing=#{run.standing}")

        {:error, refusal} ->
          out = %{"error" => "discover refused", "code" => Map.get(refusal, :code)}
          File.write!(out_path, Jason.encode!(out, pretty: true))
          IO.puts("discover REFUSED: #{Map.get(refusal, :code)}")
          System.halt(1)
      end
    else
      {:error, reason} ->
        File.write!(out_path, Jason.encode!(%{"error" => inspect(reason)}))
        IO.puts("ingest/flatten REFUSED: #{inspect(reason)}")
        System.halt(1)
    end

  ["conform", in_path, model_path, out_path, object_type] ->
    with {:ok, log} <- SmaltBridge.ingest(in_path),
         {:ok, model} <-
           model_path |> File.read!() |> Jason.decode!() |> SmaltBridge.decode_model() |> then(&{:ok, &1}) do
      case Ex4pm.conform(log, model, object_type: object_type) do
        {:ok, %Ex4pm.Run{} = run} ->
          report = run.value

          out = %{
            "object_type" => object_type,
            "fitness" => Map.get(report, :fitness),
            "observed_edge_count" => Map.get(report, :observed_edge_count),
            "deviation_count" => Map.get(report, :deviation_count),
            "deviations" =>
              Map.new(Map.get(report, :deviations, %{}), fn {{a, b}, n} -> {"#{a}->#{b}", n} end),
            "mean_case_fitness_score" => Map.get(report, :mean_case_fitness_score),
            "standing" => to_string(run.standing),
            "subject_hash" => run.subject_hash
          }

          File.write!(out_path, Jason.encode!(out, pretty: true))
          IO.puts("conform ok: fitness=#{Map.get(report, :fitness)} standing=#{run.standing}")

        {:error, refusal} ->
          File.write!(out_path, Jason.encode!(%{"error" => "conform refused", "code" => Map.get(refusal, :code)}))
          IO.puts("conform REFUSED: #{Map.get(refusal, :code)}")
          System.halt(1)
      end
    else
      {:error, reason} ->
        File.write!(out_path, Jason.encode!(%{"error" => inspect(reason)}))
        IO.puts("REFUSED: #{inspect(reason)}")
        System.halt(1)
    end

  other ->
    IO.puts("usage: powl_bridge.exs discover|conform <in.json> [<model.json>] <out.json> <object_type>")
    IO.inspect(other)
    System.halt(2)
end
