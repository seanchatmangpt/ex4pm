defmodule Ex4pm.StreamTest do
  use ExUnit.Case, async: false

  test "Broadway ingests and normalizes event observations" do
    parent = self()

    event = %{
      "id" => "e1",
      "activity" => "create",
      "timestamp" => "2026-01-01T00:00:00Z",
      "objects" => ["o1"]
    }

    objects = %{"o1" => %{"type" => "Order"}}
    name = Module.concat(__MODULE__, Pipeline)

    {:ok, pid} =
      Ex4pm.Stream.Pipeline.start_link(
        name: name,
        events: [event],
        objects: objects,
        processor_concurrency: 1,
        sink: fn normalized -> send(parent, {:normalized, normalized}) end
      )

    assert_receive {:normalized, %Ex4pm.Event{id: "e1", activity: "create"}}, 2_000
    GenServer.stop(pid)
  end
end
