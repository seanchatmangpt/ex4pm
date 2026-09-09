defmodule Ex4pm.OCEL2Test do
  @moduledoc """
  Chicago-style Real-Boundary tests for OCEL 2.0 / Event-Knowledge-Graph semantics:
  real `Ex4pm.EventLog`/`Ex4pm.Event`/`Ex4pm.ObjectRef`/`Ex4pm.ObjectRelationship`
  structs are constructed directly (no mocks, no stubs) and `Ex4pm.OCEL2` is exercised
  against that real data with state-based assertions.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.{AttributeChange, Event, EventLog, EventRelationship, ObjectRef, ObjectRelationship}
  alias Ex4pm.OCEL2
  alias Ex4pm.Subject

  defp build_log(events, objects, object_relationships \\ []) do
    normalized = %{events: events, objects: objects, object_relationships: object_relationships}

    %EventLog{
      events: events,
      objects: objects,
      object_relationships: object_relationships,
      subject: Subject.new(:event_log, normalized)
    }
  end

  test "recovers full trace for object X" do
    order = %ObjectRef{id: "order-1", type: "order"}
    item = %ObjectRef{id: "item-1", type: "item"}

    e1 = %Event{
      id: "e1",
      activity: "place order",
      timestamp: "2026-08-01T10:00:00Z",
      object_ids: ["order-1"]
    }

    e2 = %Event{
      id: "e2",
      activity: "pack item",
      timestamp: "2026-08-01T11:00:00Z",
      object_ids: ["order-1", "item-1"]
    }

    e3 = %Event{
      id: "e3",
      activity: "unrelated activity on other object",
      timestamp: "2026-08-01T12:00:00Z",
      object_ids: ["item-1"]
    }

    e4 = %Event{
      id: "e4",
      activity: "ship order",
      timestamp: "2026-08-01T09:00:00Z",
      object_ids: ["order-1"]
    }

    log = build_log([e1, e2, e3, e4], %{"order-1" => order, "item-1" => item})

    assert {:ok, trace} = OCEL2.object_trace(log, "order-1")

    # Full trace for order-1: e4 (09:00), e1 (10:00), e2 (11:00) — chronologically
    # ordered, e3 excluded because it does not reference order-1.
    assert Enum.map(trace, & &1.id) == ["e4", "e1", "e2"]
    assert Enum.map(trace, & &1.activity) == ["ship order", "place order", "pack item"]

    assert {:error, refusal} = OCEL2.object_trace(log, "does-not-exist")
    assert refusal.code == :unknown_object_reference
  end

  test "attribute change is time-traceable" do
    machine = %ObjectRef{id: "machine-1", type: "machine", attributes: %{"status" => "idle"}}

    e1 = %Event{
      id: "e1",
      activity: "start job",
      timestamp: "2026-08-01T08:00:00Z",
      object_ids: ["machine-1"],
      attributes: %{"status" => "running"}
    }

    e2 = %Event{
      id: "e2",
      activity: "temperature check",
      timestamp: "2026-08-01T08:30:00Z",
      object_ids: ["machine-1"],
      attributes: %{"status" => "running"}
    }

    e3 = %Event{
      id: "e3",
      activity: "flag overheating",
      timestamp: "2026-08-01T09:00:00Z",
      object_ids: ["machine-1"],
      attributes: %{"status" => "overheating"}
    }

    e4 = %Event{
      id: "e4",
      activity: "finish job",
      timestamp: "2026-08-01T10:00:00Z",
      object_ids: ["machine-1"],
      attributes: %{"status" => "idle"}
    }

    log = build_log([e1, e2, e3, e4], %{"machine-1" => machine})

    assert {:ok, history} = OCEL2.attribute_history(log, "machine-1", "status")

    # Not just the current value: the full traceable sequence of real changes.
    # e2 repeats "running" (same as e1) and must NOT add a duplicate entry.
    assert Enum.map(history, & &1.value) == ["running", "overheating", "idle"]
    assert [%AttributeChange{value: "running", timestamp: "2026-08-01T08:00:00Z"} | _] = history
    assert List.last(history).value == "idle"
    assert List.last(history).timestamp == "2026-08-01T10:00:00Z"
  end

  test "O2O edge carries a qualifier field" do
    order = %ObjectRef{id: "order-1", type: "order"}
    customer = %ObjectRef{id: "customer-1", type: "customer"}

    contains_rel = %ObjectRelationship{
      source_id: "order-1",
      target_id: "customer-1",
      qualifier: "placed_by"
    }

    log =
      build_log(
        [],
        %{"order-1" => order, "customer-1" => customer},
        [contains_rel]
      )

    assert [%ObjectRelationship{} = rel] = OCEL2.object_relationships_for(log, "order-1")
    assert rel.qualifier == "placed_by"
    assert rel.source_id == "order-1"
    assert rel.target_id == "customer-1"

    # Also found from the target side (edge is directed, but lookup works either way).
    assert [%ObjectRelationship{qualifier: "placed_by"}] =
             OCEL2.object_relationships_for(log, "customer-1")

    assert OCEL2.object_relationships_for(log, "unrelated-object") == []

    # And, independently: an E2O relationship also carries a real qualifier field.
    e2o = %EventRelationship{object_id: "order-1", qualifier: "resource"}
    assert e2o.qualifier == "resource"
  end
end
