defmodule Ex4pm.AttributeChange do
  @moduledoc "A single time-traceable object-attribute value change (OCEL 2.0 / EKG style)."
  @enforce_keys [:name, :value, :timestamp]
  defstruct [:name, :value, :timestamp]
end

defmodule Ex4pm.OCEL2 do
  @moduledoc """
  OCEL 2.0 / Event-Knowledge-Graph-style semantics layered on top of the canonical
  `Ex4pm.EventLog` IR (`Ex4pm.Event`, `Ex4pm.ObjectRef`, `Ex4pm.ObjectRelationship`).

  This module does not introduce a competing event/object representation — it derives
  EKG-shaped views (object traces, attribute-change history, qualifier-typed O2O
  edges) directly from the already-normalized `%Ex4pm.EventLog{}`, so every fact
  produced here stays traceable back to the canonical IR that `Ex4pm.OCEL.normalize/1`
  admits.

  Three capabilities:

    * `object_trace/2` — the full, time-ordered event sequence for a single object id
      (an Event <-> Object many-to-many relation, recoverable from either side).
    * `attribute_history/3` — the time-traceable value-change history for one dynamic
      object attribute, not just its current value.
    * `object_relationships_for/2` — the qualifier-typed O2O edges touching one object,
      in either direction.
  """

  alias Ex4pm.{AttributeChange, EventLog, Refusal}

  @doc """
  Returns the full ordered trace (event sequence) for a single object id: every event
  in `log` that references `object_id` via `object_ids` or an explicit relationship,
  sorted by `{timestamp, id}` the same way `Ex4pm.OCEL.flatten/2` orders traces.
  """
  def object_trace(%EventLog{} = log, object_id) when is_binary(object_id) do
    if Map.has_key?(log.objects, object_id) do
      trace =
        log.events
        |> Enum.filter(&(object_id in &1.object_ids))
        |> Enum.sort_by(&{&1.timestamp, &1.id})

      {:ok, trace}
    else
      {:error,
       Refusal.new(:unknown_object_reference, "object id not present in event log",
         details: %{object_id: object_id}
       )}
    end
  end

  @doc """
  Returns the time-traceable change history for a single dynamic object attribute,
  reconstructed from every event in the object's trace that carries an updated value
  for `attribute_name` (looked up in the event's `attributes` map, falling back to the
  qualifier-scoped payload on the event's relationship for `object_id` when present).

  History is a chronologically ordered list of `%Ex4pm.AttributeChange{}`, one entry
  per event that actually changes the value (a repeated identical value does not add a
  new entry) — so the *current* value is always `List.last(history).value`, but the
  full history remains inspectable, unlike a plain current-value attribute map.
  """
  def attribute_history(%EventLog{} = log, object_id, attribute_name)
      when is_binary(object_id) and is_binary(attribute_name) do
    with {:ok, trace} <- object_trace(log, object_id) do
      history =
        trace
        |> Enum.reduce([], fn event, acc ->
          case event_attribute_value(event, object_id, attribute_name) do
            {:ok, value} ->
              case acc do
                [%AttributeChange{value: ^value} | _] ->
                  acc

                _ ->
                  [
                    %AttributeChange{
                      name: attribute_name,
                      value: value,
                      timestamp: event.timestamp
                    }
                    | acc
                  ]
              end

            :not_found ->
              acc
          end
        end)
        |> Enum.reverse()

      {:ok, history}
    end
  end

  @doc """
  Returns the qualifier-typed Object-to-Object relationships that touch `object_id`,
  in either direction (as source or as target), preserving the `qualifier` field on
  each `%Ex4pm.ObjectRelationship{}`-shaped map.
  """
  def object_relationships_for(%EventLog{} = log, object_id) when is_binary(object_id) do
    Enum.filter(log.object_relationships, fn rel ->
      rel.source_id == object_id or rel.target_id == object_id
    end)
  end

  defp event_attribute_value(event, object_id, attribute_name) do
    from_relationship =
      event.relationships
      |> Enum.find(&(&1.object_id == object_id))
      |> case do
        %{attributes: attrs} when is_map(attrs) -> Map.get(attrs, attribute_name)
        _ -> nil
      end

    from_event_attrs = Map.get(event.attributes, attribute_name)

    case from_relationship || from_event_attrs do
      nil -> :not_found
      value -> {:ok, value}
    end
  end
end
