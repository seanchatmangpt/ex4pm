defmodule Ex4pm.Core.OLAPTest do
  @moduledoc """
  Chicago-style state-based tests for `Ex4pm.Core.OLAP`. Builds a real, small,
  hand-constructed OCEL-shaped fixture (events with timestamps/attributes) via
  the real `Ex4pm.OCEL.normalize/1` normalizer -- no mocks -- and asserts on the
  real returned data shapes/values after each slice/dice/roll_up/drill_down call.
  """

  use ExUnit.Case, async: true

  alias Ex4pm.Core.OLAP
  alias Ex4pm.EventLog
  alias Ex4pm.OCEL

  # Fixture: 5 events spanning two days ("2026-08-30", "2026-08-31") within the
  # same month ("2026-08"), across two activities ("order", "ship") and two
  # regions ("east", "west"), referencing two real objects.
  defp fixture_log do
    raw = %{
      "objects" => %{
        "o1" => %{"type" => "order"},
        "o2" => %{"type" => "order"}
      },
      "events" => [
        %{
          "id" => "e1",
          "activity" => "order",
          "timestamp" => "2026-08-30T09:00:00Z",
          "object_ids" => ["o1"],
          "attributes" => %{"region" => "east"}
        },
        %{
          "id" => "e2",
          "activity" => "order",
          "timestamp" => "2026-08-30T10:00:00Z",
          "object_ids" => ["o2"],
          "attributes" => %{"region" => "west"}
        },
        %{
          "id" => "e3",
          "activity" => "ship",
          "timestamp" => "2026-08-31T08:00:00Z",
          "object_ids" => ["o1"],
          "attributes" => %{"region" => "east"}
        },
        %{
          "id" => "e4",
          "activity" => "ship",
          "timestamp" => "2026-08-31T09:00:00Z",
          "object_ids" => ["o2"],
          "attributes" => %{"region" => "west"}
        },
        %{
          "id" => "e5",
          "activity" => "ship",
          "timestamp" => "2026-08-31T10:00:00Z",
          "object_ids" => ["o1"],
          "attributes" => %{"region" => "east"}
        }
      ]
    }

    assert {:ok, %EventLog{} = log} = OCEL.normalize(raw)
    log
  end

  describe "slice/3" do
    test "filters events to one activity value, narrowing objects to what survives" do
      log = fixture_log()

      sliced = OLAP.slice(log, :activity, "ship")

      assert %EventLog{} = sliced
      assert Enum.map(sliced.events, & &1.id) |> Enum.sort() == ["e3", "e4", "e5"]
      assert Enum.all?(sliced.events, &(&1.activity == "ship"))
      # both o1 and o2 are still referenced by at least one "ship" event
      assert Map.keys(sliced.objects) |> Enum.sort() == ["o1", "o2"]
      assert sliced.metadata.event_count == 3
    end

    test "filters events to one attribute-dimension value" do
      log = fixture_log()

      sliced = OLAP.slice(log, {:attribute, "region"}, "east")

      assert Enum.map(sliced.events, & &1.id) |> Enum.sort() == ["e1", "e3", "e5"]
      assert Enum.all?(sliced.events, &(&1.attributes["region"] == "east"))
      # only o1 is referenced by "east" events; o2 is dropped from the slice
      assert Map.keys(sliced.objects) == ["o1"]
    end

    test "filters events to one day" do
      log = fixture_log()

      sliced = OLAP.slice(log, :day, "2026-08-31")

      assert Enum.map(sliced.events, & &1.id) |> Enum.sort() == ["e3", "e4", "e5"]
    end
  end

  describe "dice/2" do
    test "filters along multiple dimensions simultaneously (AND semantics)" do
      log = fixture_log()

      diced = OLAP.dice(log, [{:activity, "ship"}, {{:attribute, "region"}, "east"}])

      assert Enum.map(diced.events, & &1.id) |> Enum.sort() == ["e3", "e5"]

      assert Enum.all?(
               diced.events,
               &(&1.activity == "ship" and &1.attributes["region"] == "east")
             )
    end

    test "an unsatisfiable combination of filters yields zero events" do
      log = fixture_log()

      diced = OLAP.dice(log, [{:activity, "order"}, {:day, "2026-08-31"}])

      assert diced.events == []
      assert diced.objects == %{}
      assert diced.metadata.event_count == 0
    end
  end

  describe "roll_up/3" do
    test "aggregates event counts up from day to month" do
      log = fixture_log()

      by_day = OLAP.roll_up(log, :day, &length/1)
      assert by_day == %{"2026-08-30" => 2, "2026-08-31" => 3}

      by_month = OLAP.roll_up(log, :month, &length/1)
      assert by_month == %{"2026-08" => 5}

      # coarsening day -> month preserves the total event count
      assert Enum.sum(Map.values(by_day)) == Enum.sum(Map.values(by_month))
    end

    test "aggregates with a custom aggregate function (distinct activities per day)" do
      log = fixture_log()

      activities_by_day =
        OLAP.roll_up(log, :day, fn events ->
          events |> Enum.map(& &1.activity) |> Enum.uniq() |> Enum.sort()
        end)

      assert activities_by_day == %{
               "2026-08-30" => ["order"],
               "2026-08-31" => ["ship"]
             }
    end

    test "rolls up an attribute dimension" do
      log = fixture_log()

      by_region = OLAP.roll_up(log, {:attribute, "region"}, &length/1)

      assert by_region == %{"east" => 3, "west" => 2}
    end
  end

  describe "drill_down/3" do
    test "expands the month dimension back to day, recovering the roll_up totals" do
      log = fixture_log()

      expanded = OLAP.drill_down(log, :month, :day)

      assert Map.keys(expanded) == ["2026-08"]
      inner = expanded["2026-08"]
      assert Map.keys(inner) |> Enum.sort() == ["2026-08-30", "2026-08-31"]
      assert length(inner["2026-08-30"]) == 2
      assert length(inner["2026-08-31"]) == 3

      # structural inverse: summing the drill-down's inner group sizes recovers
      # the same counts as roll_up/3 on the finer dimension directly
      by_day = OLAP.roll_up(log, :day, &length/1)
      assert Map.new(inner, fn {k, v} -> {k, length(v)} end) == by_day
    end

    test "drills activity down into region, exposing the real per-cell event lists" do
      log = fixture_log()

      expanded = OLAP.drill_down(log, :activity, {:attribute, "region"})

      assert Map.keys(expanded) |> Enum.sort() == ["order", "ship"]
      assert Map.keys(expanded["order"]) |> Enum.sort() == ["east", "west"]
      assert Map.keys(expanded["ship"]) |> Enum.sort() == ["east", "west"]

      ship_east_ids = expanded["ship"]["east"] |> Enum.map(& &1.id) |> Enum.sort()
      assert ship_east_ids == ["e3", "e5"]
    end
  end
end
