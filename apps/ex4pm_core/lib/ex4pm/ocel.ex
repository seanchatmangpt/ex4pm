defmodule Ex4pm.Event do
  @moduledoc "Canonical event observation."
  @enforce_keys [:id, :activity, :timestamp]
  defstruct [:id, :activity, :timestamp, object_ids: [], attributes: %{}]
end

defmodule Ex4pm.ObjectRef do
  @moduledoc "Canonical object-centric process object."
  @enforce_keys [:id, :type]
  defstruct [:id, :type, attributes: %{}]
end

defmodule Ex4pm.EventLog do
  @moduledoc "Admitted event-log semantic IR."
  @enforce_keys [:events, :objects, :subject]
  defstruct [:events, :objects, :subject, source_format: :ocel_v2, metadata: %{}]
end

defmodule Ex4pm.OCEL do
  @moduledoc "OCEL-v2-tolerant normalization into the canonical event-log IR."

  alias Ex4pm.{Event, EventLog, ObjectRef, Refusal, Subject}

  @event_keys ["events", :events]
  @object_keys ["objects", :objects]

  def normalize(%EventLog{} = log), do: {:ok, log}

  def normalize(raw) when is_map(raw) do
    with {:ok, raw_events} <- fetch_any(raw, @event_keys, :missing_events),
         {:ok, raw_objects} <- fetch_any(raw, @object_keys, :missing_objects),
         {:ok, objects} <- normalize_objects(raw_objects),
         {:ok, events} <- normalize_events(raw_events),
         :ok <- validate_references(events, objects) do
      normalized = %{events: events, objects: objects}

      {:ok,
       %EventLog{
         events: events,
         objects: objects,
         subject: Subject.new(:event_log, normalized),
         source_format: :ocel_v2,
         metadata: %{event_count: length(events), object_count: map_size(objects)}
       }}
    end
  end

  def normalize(other) do
    {:error, Refusal.new(:invalid_observation, "event observation must be a map", subject: other)}
  end

  def flatten(%EventLog{} = log, object_type) when is_binary(object_type) or is_atom(object_type) do
    selected =
      log.objects
      |> Map.values()
      |> Enum.filter(&(to_string(&1.type) == to_string(object_type)))

    traces =
      selected
      |> Enum.map(fn object ->
        events =
          log.events
          |> Enum.filter(&(object.id in &1.object_ids))
          |> Enum.sort_by(&event_sort_key/1)

        {object.id, events}
      end)
      |> Enum.reject(fn {_id, events} -> events == [] end)
      |> Map.new()

    if map_size(traces) == 0 do
      {:error,
       Refusal.new(:empty_flattening, "no events reference the requested object type",
         details: %{object_type: object_type}
       )}
    else
      {:ok, traces}
    end
  end

  def flatten(%EventLog{} = log, nil) do
    {:ok, %{"__event_log__" => Enum.sort_by(log.events, &event_sort_key/1)}}
  end

  defp normalize_objects(objects) when is_map(objects) do
    objects
    |> Enum.reduce_while({:ok, %{}}, fn {id, raw}, {:ok, acc} ->
      case normalize_object(raw, id) do
        {:ok, object} -> {:cont, {:ok, Map.put(acc, object.id, object)}}
        error -> {:halt, error}
      end
    end)
  end

  defp normalize_objects(objects) when is_list(objects) do
    objects
    |> Enum.reduce_while({:ok, %{}}, fn raw, {:ok, acc} ->
      case normalize_object(raw, nil) do
        {:ok, object} -> {:cont, {:ok, Map.put(acc, object.id, object)}}
        error -> {:halt, error}
      end
    end)
  end

  defp normalize_objects(other) do
    {:error, Refusal.new(:invalid_objects, "objects must be a map or list", subject: other)}
  end

  defp normalize_object(raw, fallback_id) when is_map(raw) do
    id = value(raw, ["id", :id, "ocel:oid", :"ocel:oid"]) || fallback_id
    type = value(raw, ["type", :type, "ocel:type", :"ocel:type"])

    cond do
      is_nil(id) -> {:error, Refusal.new(:missing_object_id, "object is missing identity", subject: raw)}
      is_nil(type) -> {:error, Refusal.new(:missing_object_type, "object is missing type", subject: raw)}
      true -> {:ok, %ObjectRef{id: to_string(id), type: type, attributes: drop_known_object_keys(raw)}}
    end
  end

  defp normalize_object(other, _fallback_id) do
    {:error, Refusal.new(:invalid_object, "object must be a map", subject: other)}
  end

  defp normalize_events(events) when is_map(events) do
    events
    |> Enum.reduce_while({:ok, []}, fn {id, raw}, {:ok, acc} ->
      case normalize_event(raw, id) do
        {:ok, event} -> {:cont, {:ok, [event | acc]}}
        error -> {:halt, error}
      end
    end)
    |> then(fn
      {:ok, events} -> {:ok, Enum.sort_by(events, &event_sort_key/1)}
      error -> error
    end)
  end

  defp normalize_events(events) when is_list(events) do
    events
    |> Enum.reduce_while({:ok, []}, fn raw, {:ok, acc} ->
      case normalize_event(raw, nil) do
        {:ok, event} -> {:cont, {:ok, [event | acc]}}
        error -> {:halt, error}
      end
    end)
    |> then(fn
      {:ok, events} -> {:ok, Enum.sort_by(events, &event_sort_key/1)}
      error -> error
    end)
  end

  defp normalize_events(other) do
    {:error, Refusal.new(:invalid_events, "events must be a map or list", subject: other)}
  end

  defp normalize_event(raw, fallback_id) when is_map(raw) do
    id = value(raw, ["id", :id, "ocel:eid", :"ocel:eid"]) || fallback_id
    activity = value(raw, ["activity", :activity, "type", :type, "ocel:activity", :"ocel:activity"])
    timestamp = value(raw, ["timestamp", :timestamp, "time", :time, "ocel:timestamp", :"ocel:timestamp"])
    object_ids = extract_object_ids(raw)

    cond do
      is_nil(id) -> {:error, Refusal.new(:missing_event_id, "event is missing identity", subject: raw)}
      is_nil(activity) -> {:error, Refusal.new(:missing_activity, "event is missing activity", subject: raw)}
      is_nil(timestamp) -> {:error, Refusal.new(:missing_timestamp, "event is missing timestamp", subject: raw)}
      true ->
        {:ok,
         %Event{
           id: to_string(id),
           activity: to_string(activity),
           timestamp: normalize_timestamp(timestamp),
           object_ids: Enum.map(object_ids, &to_string/1) |> Enum.uniq() |> Enum.sort(),
           attributes: drop_known_event_keys(raw)
         }}
    end
  end

  defp normalize_event(other, _fallback_id) do
    {:error, Refusal.new(:invalid_event, "event must be a map", subject: other)}
  end

  defp extract_object_ids(raw) do
    direct = value(raw, ["object_ids", :object_ids, "objects", :objects, "ocel:omap", :"ocel:omap"])

    case direct do
      nil ->
        raw
        |> value(["relationships", :relationships])
        |> List.wrap()
        |> Enum.map(fn
          relationship when is_map(relationship) -> value(relationship, ["objectId", :objectId, "object_id", :object_id])
          id -> id
        end)
        |> Enum.reject(&is_nil/1)

      list when is_list(list) ->
        Enum.map(list, fn
          relationship when is_map(relationship) ->
            value(relationship, ["objectId", :objectId, "object_id", :object_id, "id", :id])

          id ->
            id
        end)
        |> Enum.reject(&is_nil/1)

      single ->
        [single]
    end
  end

  defp validate_references(events, objects) do
    missing =
      events
      |> Enum.flat_map(& &1.object_ids)
      |> Enum.uniq()
      |> Enum.reject(&Map.has_key?(objects, &1))
      |> Enum.sort()

    if missing == [] do
      :ok
    else
      {:error,
       Refusal.new(:unknown_object_reference, "event references unknown object identities",
         details: %{object_ids: missing}
       )}
    end
  end

  defp fetch_any(map, keys, code) do
    case Enum.find_value(keys, fn key -> if Map.has_key?(map, key), do: {:found, Map.get(map, key)} end) do
      {:found, value} -> {:ok, value}
      nil -> {:error, Refusal.new(code, "required OCEL collection is missing")}
    end
  end

  defp value(map, keys), do: Enum.find_value(keys, &Map.get(map, &1))

  defp normalize_timestamp(%DateTime{} = timestamp), do: DateTime.to_iso8601(timestamp)
  defp normalize_timestamp(%NaiveDateTime{} = timestamp), do: NaiveDateTime.to_iso8601(timestamp)
  defp normalize_timestamp(timestamp), do: to_string(timestamp)

  defp event_sort_key(event), do: {event.timestamp, event.id}

  defp drop_known_object_keys(map) do
    Map.drop(map, ["id", :id, "ocel:oid", :"ocel:oid", "type", :type, "ocel:type", :"ocel:type"])
  end

  defp drop_known_event_keys(map) do
    Map.drop(map, [
      "id",
      :id,
      "ocel:eid",
      :"ocel:eid",
      "activity",
      :activity,
      "type",
      :type,
      "ocel:activity",
      :"ocel:activity",
      "timestamp",
      :timestamp,
      "time",
      :time,
      "ocel:timestamp",
      :"ocel:timestamp",
      "object_ids",
      :object_ids,
      "objects",
      :objects,
      "ocel:omap",
      :"ocel:omap",
      "relationships",
      :relationships
    ])
  end
end
