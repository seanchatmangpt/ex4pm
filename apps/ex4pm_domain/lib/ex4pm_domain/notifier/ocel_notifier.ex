defmodule Ex4pmDomain.Notifier.OcelNotifier do
  @moduledoc """
  Universal Ash.Notifier that automatically intercepts Ash Resource lifecycle actions
  and transforms them into standard IEEE OCEL 2.0 events.

  Usage in any Ash.Resource:
  ```elixir
  use Ash.Resource,
    notifiers: [Ex4pmDomain.Notifier.OcelNotifier]
  ```
  """

  use Ash.Notifier

  @impl Ash.Notifier
  def notify(%Ash.Notifier.Notification{} = notification) do
    event = transform_notification(notification)

    if Code.ensure_loaded?(Ex4pm.Stream.Ingest) and
         function_exported?(Ex4pm.Stream.Ingest, :ingest_batch, 1) do
      try do
        envelope = %{
          "schema" => "chatgpt-cloud-ocel/1",
          "producer" => %{
            "agent_id" => "ash_notifier",
            "runtime" => "beam",
            "resource" => inspect(notification.resource)
          },
          "sequence" => System.unique_integer([:positive]),
          "digest" => :crypto.hash(:sha256, event["id"]) |> Base.encode16(case: :lower),
          "events" => [event]
        }

        apply(Ex4pm.Stream.Ingest, :ingest_batch, [envelope])
      rescue
        _ -> {:ok, event}
      end
    else
      {:ok, event}
    end
  end

  def notify(_), do: :ok

  @doc "Transforms an Ash notification into an OCEL 2.0 event map."
  def transform_notification(%{resource: _, action: _, data: _} = notif) do
    resource_name =
      notif.resource
      |> Module.split()
      |> List.last()

    action_name = to_string(notif.action.name)
    activity_name = "#{resource_name}.#{action_name}"

    record_id =
      cond do
        is_struct(notif.data) and Map.has_key?(notif.data, :id) ->
          to_string(notif.data.id)

        is_map(notif.data) and Map.has_key?(notif.data, :id) ->
          to_string(notif.data.id)

        is_map(notif.data) and Map.has_key?(notif.data, "id") ->
          to_string(notif.data["id"])

        true ->
          "obj_#{System.unique_integer([:positive])}"
      end

    actor =
      cond do
        notif.actor && is_map(notif.actor) && Map.has_key?(notif.actor, :id) ->
          to_string(notif.actor.id)

        notif.actor && is_map(notif.actor) && Map.has_key?(notif.actor, "id") ->
          to_string(notif.actor["id"])

        notif.actor ->
          to_string(notif.actor)

        true ->
          "system"
      end

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    event_id = "ev_#{System.unique_integer([:positive])}"

    # Extract dynamic attributes from changeset or data
    attributes =
      if is_struct(notif.data) do
        notif.data
        |> Map.from_struct()
        |> Map.drop([:__meta__, :__metadata__, :calculations, :aggregates])
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new(fn {k, v} -> {to_string(k), v} end)
      else
        %{}
      end
      |> Map.put("actor", actor)
      |> Map.put("action_type", to_string(notif.action.type))
      |> Map.put("resource", resource_name)

    %{
      "id" => event_id,
      "activity" => activity_name,
      "timestamp" => timestamp,
      "objects" => [record_id],
      "attributes" => attributes,
      "relationships" => [
        %{"object_id" => record_id, "qualifier" => "target"},
        %{"object_id" => actor, "qualifier" => "actor"}
      ]
    }
  end
end
