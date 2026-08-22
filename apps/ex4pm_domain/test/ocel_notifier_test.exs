defmodule Ex4pmDomain.Notifier.OcelNotifierTest do
  use ExUnit.Case, async: true

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
end
