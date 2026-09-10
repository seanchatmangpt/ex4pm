defmodule Ex4pmDomain.Notifier.OcelNotifierTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Evidence.Store
  alias Ex4pmDomain.Notifier.OcelNotifier

  test "transforms Ash action notification into standard OCEL 2.0 event" do
    fake_notif = %{
      resource: Ex4pmDomain.Agent,
      action: %{name: :create, type: :create},
      data: %{id: "agent_42", agent_id: "agent_42", runtime: "beam"},
      actor: %{id: "admin_user"}
    }

    event = OcelNotifier.transform_notification(fake_notif)

    assert event["activity"] == "Agent.create"
    assert event["attributes"]["actor"] == "admin_user"
    assert event["attributes"]["action_type"] == "create"
    assert event["objects"] == ["agent_42"]
    assert length(event["relationships"]) == 2
  end

  test "notify/1 actually ingests the event into the real evidence store (no dead-code fallthrough)" do
    unique_id = "agent_#{System.unique_integer([:positive])}"

    notification = %Ash.Notifier.Notification{
      resource: Ex4pmDomain.Agent,
      action: %{name: :create, type: :create},
      data: %{id: unique_id, runtime: "beam"},
      actor: %{id: "admin_user"}
    }

    assert {:ok, result} = OcelNotifier.notify(notification)
    assert result.status == :ingested
    assert result.event_count == 1
    assert result.agent_id == "ash_notifier"

    # Verify the ingestion actually produced real receipts in the shared, running
    # Ex4pm.Evidence.Store (started under Ex4pm.Application), not a fake success tuple.
    matching_receipts =
      Store.all()
      |> Enum.filter(fn receipt -> receipt.metadata[:agent_id] == "ash_notifier" end)

    assert matching_receipts != [],
           "expected the notifier's ingestion to leave a real receipt in Ex4pm.Evidence.Store"

    assert Enum.any?(matching_receipts, fn receipt -> receipt.phase == :outcome end),
           "expected a completed :outcome receipt proving the ingest ran to completion"
  end
end
