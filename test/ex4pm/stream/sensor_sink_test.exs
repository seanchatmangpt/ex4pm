defmodule Ex4pm.Stream.SensorSinkTest do
  @moduledoc """
  Chicago-style state-based test: feeds a real sequence of numeric sensor
  samples through `Ex4pm.Stream.SensorSink.sample_all/2` and asserts on the
  real resulting list of abstracted `%Ex4pm.Event{}` structs. No mocks.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.Event
  alias Ex4pm.Stream.SensorSink

  test "threshold-crossing rule abstracts a raw numeric signal into discrete events" do
    sink = SensorSink.new(threshold: 50.0)

    readings = [
      {10.0, 1, "temp-1"},
      {20.0, 2, "temp-1"},
      {60.0, 3, "temp-1"},
      {65.0, 4, "temp-1"},
      {40.0, 5, "temp-1"},
      {90.0, 6, "temp-1"}
    ]

    {final_state, events} = SensorSink.sample_all(sink, readings)

    assert length(events) == 3

    assert Enum.map(events, & &1.activity) == [
             "threshold_crossed_above",
             "threshold_crossed_below",
             "threshold_crossed_above"
           ]

    assert Enum.map(events, & &1.timestamp) == [3, 5, 6]
    assert Enum.all?(events, fn %Event{object_ids: ids} -> ids == ["temp-1"] end)
    assert Enum.map(events, fn %Event{attributes: attrs} -> attrs.value end) == [60.0, 40.0, 90.0]

    assert final_state.emitted == 3
    assert final_state.last_state == %{"temp-1" => :above}
  end

  test "independent per-sensor correlation: crossing on one sensor does not affect another" do
    sink = SensorSink.new(threshold: 0.0)

    readings = [
      {-1.0, 1, "s1"},
      {-1.0, 2, "s2"},
      {1.0, 3, "s1"},
      {-2.0, 4, "s2"}
    ]

    {_state, events} = SensorSink.sample_all(sink, readings)

    assert Enum.map(events, fn %Event{id: id} -> id end) |> length() == 1
    assert [%Event{activity: "threshold_crossed_above", object_ids: ["s1"]}] = events
  end

  test "samples that stay within the same band emit no event" do
    sink = SensorSink.new(threshold: 100.0)
    readings = for i <- 1..10, do: {5.0 + i, i, "steady"}

    {_state, events} = SensorSink.sample_all(sink, readings)

    assert events == []
  end
end
