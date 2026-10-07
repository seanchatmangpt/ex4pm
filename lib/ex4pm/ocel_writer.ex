defmodule Ex4pm.OCEL.Writer do
  @moduledoc """
  OCEL 2.0 JSON writer for the canonical event-log IR (`Ex4pm.EventLog`).

  The engine owns the wire format: this module is the DOWN-STACK writer that
  pairs with the reader `Ex4pm.OCEL.normalize/1`. Consumers (ash_ex4pm,
  ash_pplan) project from the canonical IR; they do not build the OCEL 2.0
  envelope themselves.

  Three laws, each witnessed by a court in `test/ocel_writer_test.exs`:

    - Round-trip: `Ex4pm.OCEL.normalize(Jason.decode!(encode(log)))`
      reconstructs the same events and objects.
    - Byte-identity: `IO.iodata_to_binary(encode_iodata(log)) == encode(log)`
      -- both paths share one chunk builder, so identity holds by construction.
    - Gzip round-trip: `:zlib.gunzip(gzip) == encode(log)`.

  Follows the reader's never-raise contract: returns `{:error, %Ex4pm.Refusal{}}`
  for non-`EventLog` subjects instead of raising.
  """

  alias Ex4pm.{EventLog, ObjectRef, Refusal}

  @doc "Encodes an `Ex4pm.EventLog` as OCEL 2.0 JSON."
  @spec encode(EventLog.t()) :: {:ok, String.t()} | {:error, Refusal.t()}
  def encode(%EventLog{} = log), do: {:ok, IO.iodata_to_binary(encode_iodata!(log))}

  def encode(other) do
    {:error,
     Refusal.new(:invalid_event_log, "OCEL writer requires an Ex4pm.EventLog", subject: other)}
  end

  @doc """
  Chunked encode: emits the OCEL 2.0 envelope as iodata, one
  `Jason.encode_to_iodata!/1` chunk per event and per object, so a 100k-event
  log never materializes one giant encoded term. Byte-identical to `encode/1`.
  """
  @spec encode_iodata(EventLog.t()) :: {:ok, iodata()} | {:error, Refusal.t()}
  def encode_iodata(%EventLog{} = log), do: {:ok, encode_iodata!(log)}

  def encode_iodata(other) do
    {:error,
     Refusal.new(:invalid_event_log, "OCEL writer requires an Ex4pm.EventLog", subject: other)}
  end

  @doc "Gzips the OCEL 2.0 JSON encoding of `log` (:zlib, no new deps)."
  @spec encode_gzip(EventLog.t()) :: {:ok, binary()} | {:error, Refusal.t()}
  def encode_gzip(%EventLog{} = log), do: {:ok, :zlib.gzip(IO.iodata_to_binary(encode_iodata!(log)))}

  def encode_gzip(other) do
    {:error,
     Refusal.new(:invalid_event_log, "OCEL writer requires an Ex4pm.EventLog", subject: other)}
  end

  # Single chunk builder shared by all three entry points; encode/1's
  # IO.iodata_to_binary of this exact iolist IS the byte-identity law.
  defp encode_iodata!(%EventLog{} = log) do
    events = Enum.sort_by(log.events, &{&1.timestamp, &1.id})
    objects = log.objects |> Map.values() |> Enum.sort_by(& &1.id)

    [
      ~s({"objectTypes":),
      Jason.encode_to_iodata!(object_types(objects)),
      ~s(,"eventTypes":),
      Jason.encode_to_iodata!(event_types(events)),
      ~s(,"objects":[),
      objects |> Enum.map(&object_doc(&1) |> Jason.encode_to_iodata!()) |> Enum.intersperse(?,),
      ~s(],"events":[),
      events |> Enum.map(&event_doc(&1) |> Jason.encode_to_iodata!()) |> Enum.intersperse(?,),
      "]}"
    ]
  end

  defp object_types(objects) do
    objects
    |> Map.new(&{to_string(&1.type), true})
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(&%{"name" => &1, "attributes" => []})
  end

  defp event_types(events) do
    events
    |> Map.new(&{&1.activity, true})
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(fn activity ->
      keys = attribute_names_for(events, activity)

      %{"name" => activity, "attributes" => Enum.map(keys, &%{"name" => &1, "type" => "string"})}
    end)
  end

  defp attribute_names_for(events, activity) do
    events
    |> Enum.filter(&(&1.activity == activity))
    |> Enum.flat_map(&Map.keys(&1.attributes))
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp object_doc(%ObjectRef{} = object) do
    %{
      "id" => object.id,
      "type" => to_string(object.type),
      "attributes" => object_attribute_pairs(object.attributes)
    }
  end

  defp object_attribute_pairs(attributes) do
    attributes
    |> Enum.sort_by(fn {name, _} -> to_string(name) end)
    |> Enum.flat_map(fn {name, entries} ->
      Enum.map(entries, fn %{value: value, time: time} ->
        pair = %{"name" => to_string(name), "value" => value}
        if time, do: Map.put(pair, "time", time), else: pair
      end)
    end)
  end

  defp event_doc(event) do
    %{
      "id" => event.id,
      "type" => event.activity,
      "time" => to_string(event.timestamp),
      "attributes" =>
        event.attributes
        |> Enum.sort_by(fn {name, _} -> to_string(name) end)
        |> Enum.map(fn {name, value} -> %{"name" => to_string(name), "value" => value} end),
      "relationships" =>
        case event.relationships do
          [] -> Enum.map(event.object_ids, &%{"objectId" => &1, "qualifier" => "involved"})
          rels -> Enum.map(rels, &%{"objectId" => &1.object_id, "qualifier" => &1.qualifier})
        end
    }
  end
end
