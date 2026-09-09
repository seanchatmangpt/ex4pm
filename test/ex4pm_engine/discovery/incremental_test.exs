defmodule Ex4pm.Engine.Discovery.IncrementalTest do
  @moduledoc """
  Chicago-style state-based cross-check: streams events one at a time through
  `Ex4pm.Engine.Discovery.Incremental.update/2` and asserts the final
  incrementally-built DFG equals the batch-computed DFG (`from_events/1`) for
  the identical event sequence. No mocks — both paths run the real module.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.Engine.Discovery.Incremental
  alias Ex4pm.Event

  defp event(id, activity, ts, object_ids) do
    %Event{id: id, activity: activity, timestamp: ts, object_ids: object_ids}
  end

  test "incremental single-event folds equal batch computation for a multi-case OCEL stream" do
    events = [
      event("e1", "admit", 1, ["case_a"]),
      event("e2", "admit", 2, ["case_b"]),
      event("e3", "construct", 3, ["case_a"]),
      event("e4", "verify", 4, ["case_a"]),
      event("e5", "construct", 5, ["case_b"]),
      event("e6", "brce", 6, ["case_a"]),
      event("e7", "do", 7, ["case_a"]),
      event("e8", "verify", 8, ["case_b"])
    ]

    incremental_state =
      events
      |> Enum.reduce(Incremental.new(), fn evt, state -> Incremental.update(state, evt) end)
      |> Incremental.finalize()

    batch_state = Incremental.from_events(events)

    assert Incremental.dfg(incremental_state) == Incremental.dfg(batch_state)
    assert incremental_state.activities == batch_state.activities
    assert incremental_state.starts == batch_state.starts
    assert incremental_state.ends == batch_state.ends
    assert incremental_state.event_count == batch_state.event_count

    # Concretely verify the expected DFG shape for this sequence:
    # case_a: admit -> construct -> verify -> brce -> do
    # case_b: admit -> construct -> verify
    assert Incremental.dfg(incremental_state) == %{
             {"admit", "construct"} => 2,
             {"construct", "verify"} => 2,
             {"verify", "brce"} => 1,
             {"brce", "do"} => 1
           }

    assert incremental_state.starts == %{"admit" => 2}
    assert incremental_state.ends == %{"do" => 1, "verify" => 1}
    assert incremental_state.event_count == 8
  end

  test "update/2 performs a real single-event fold without rescanning prior events" do
    state0 = Incremental.new()
    state1 = Incremental.update(state0, event("e1", "a", 1, ["c1"]))
    assert state1.event_count == 1
    assert Incremental.dfg(state1) == %{}

    state2 = Incremental.update(state1, event("e2", "b", 2, ["c1"]))
    assert state2.event_count == 2
    assert Incremental.dfg(state2) == %{{"a", "b"} => 1}

    # Prior counters carried forward unchanged in structure, only the new edge added.
    assert state2.activities == %{"a" => 1, "b" => 1}
  end

  test "single-case default correlation (no object_ids) treats the stream as one global case" do
    events = [
      event("e1", "start", 1, []),
      event("e2", "middle", 2, []),
      event("e3", "end", 3, [])
    ]

    batch = Incremental.from_events(events)

    assert Incremental.dfg(batch) == %{
             {"start", "middle"} => 1,
             {"middle", "end"} => 1
           }
  end
end
