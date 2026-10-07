defmodule Ex4pm.OCEL.WriterTest do
  @moduledoc """
  Chicago-style courts for `Ex4pm.OCEL.Writer`. Real collaborators, no mocks:
  a real `Ex4pm.EventLog` is encoded, really decoded with Jason, and really
  re-normalized through the real reader. State-based assertions only.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.{Event, EventLog, OCEL, ObjectRef, Subject}

  defp build_log(events, objects, object_relationships \\ []) do
    normalized = %{events: events, objects: objects, object_relationships: object_relationships}

    %EventLog{
      events: events,
      objects: objects,
      object_relationships: object_relationships,
      subject: Subject.new(:event_log, normalized)
    }
  end

  defp sample_log do
    order =
      %ObjectRef{
        id: "order-1",
        type: :order,
        attributes: %{
          "status" => [
            %{value: "pending", time: nil},
            %{value: "shipped", time: "2026-01-02T00:00:00Z"}
          ]
        }
      }

    item = %ObjectRef{id: "item-1", type: "item"}
    objects = %{"order-1" => order, "item-1" => item}

    e1 = %Event{
      id: "e1",
      activity: "create",
      timestamp: "2026-01-01T00:00:00Z",
      object_ids: ["item-1", "order-1"],
      relationships: [
        %{object_id: "order-1", qualifier: "places"},
        %{object_id: "item-1", qualifier: "involved"}
      ]
    }

    e2 = %Event{
      id: "e2",
      activity: "ship",
      timestamp: "2026-01-02T00:00:00Z",
      object_ids: ["order-1"],
      relationships: [%{object_id: "order-1", qualifier: "involved"}],
      attributes: %{"carrier" => "post"}
    }

    build_log([e1, e2], objects)
  end

  test "round-trip: normalize(encode(log)) reconstructs same events and objects" do
    log = sample_log()
    {:ok, json} = Ex4pm.OCEL.Writer.encode(log)
    assert is_binary(json)

    {:ok, reparsed} = OCEL.normalize(Jason.decode!(json))
    assert {:ok, reparsed} = {:ok, reparsed}

    assert length(reparsed.events) == 2
    assert map_size(reparsed.objects) == 2

    for {orig, back} <- Enum.zip(Enum.sort_by(log.events, &{&1.timestamp, &1.id}), reparsed.events) do
      assert back.id == orig.id
      assert back.activity == orig.activity
      assert back.timestamp == orig.timestamp
      assert back.object_ids == Enum.sort(orig.object_ids)
    end

    for {id, orig} <- log.objects do
      back = reparsed.objects[id]
      assert back.id == id
      assert to_string(orig.type) == back.type

      for {name, entries} <- orig.attributes do
        values =
          back.attributes[name]
          |> List.wrap()
          |> Enum.map(& &1.value)

        assert Enum.all?(entries, &(&1.value in values))
      end
    end
  end

  test "byte-identity: iodata_to_binary(encode_iodata) == encode" do
    log = sample_log()
    {:ok, json} = Ex4pm.OCEL.Writer.encode(log)
    {:ok, iodata} = Ex4pm.OCEL.Writer.encode_iodata(log)
    assert IO.iodata_to_binary(iodata) == json
  end

  test "gzip round-trip: gunzip(encode_gzip) == encode" do
    log = sample_log()
    {:ok, gz} = Ex4pm.OCEL.Writer.encode_gzip(log)
    {:ok, json} = Ex4pm.OCEL.Writer.encode(log)
    assert :zlib.gunzip(gz) == json
  end

  test "non-EventLog subject refuses, never raises" do
    assert {:error, %Ex4pm.Refusal{}} = Ex4pm.OCEL.Writer.encode(%{"events" => []})
    assert {:error, %Ex4pm.Refusal{}} = Ex4pm.OCEL.Writer.encode_iodata("nope")
    assert {:error, %Ex4pm.Refusal{}} = Ex4pm.OCEL.Writer.encode_gzip(nil)
  end

  test "scaling: reductions/event flat across 1k vs 10k events (+/-5%)" do
    warm = build_generated_log(200)
    {:ok, _} = Ex4pm.OCEL.Writer.encode_iodata(warm)

    small = reductions_per_event(1_000)
    large = reductions_per_event(10_000)

    ratio = large / small
    assert ratio >= 0.95, "10k per-event reductions #{large} below 1k #{small}"
    assert ratio <= 1.05, "10k per-event reductions #{large} exceeds 1k #{small} (ratio #{ratio})"
  end

  defp reductions_per_event(n) do
    log = build_generated_log(n)

    {:reductions, before} = :erlang.process_info(self(), :reductions)
    {:ok, _} = Ex4pm.OCEL.Writer.encode_iodata(log)
    {:reductions, after_} = :erlang.process_info(self(), :reductions)

    (after_ - before) / n
  end

  defp build_generated_log(n) do
    events =
      Enum.map(1..n, fn i ->
        %Event{
          id: "e#{i}",
          activity: "act#{rem(i, 5)}",
          timestamp: iso(i),
          object_ids: ["o#{rem(i, 50)}"],
          relationships: [%{object_id: "o#{rem(i, 50)}", qualifier: "involved"}],
          attributes: %{"seq" => i}
        }
      end)

    objects =
      Map.new(0..49, fn i ->
        {"o#{i}", %ObjectRef{id: "o#{i}", type: "thing", attributes: %{"n" => [%{value: i, time: nil}]}}}
      end)

    normalized = %{events: events, objects: objects, object_relationships: []}

    %EventLog{
      events: events,
      objects: objects,
      object_relationships: [],
      subject: Subject.new(:event_log, normalized)
    }
  end

  defp iso(i) do
    DateTime.new!(Date.new!(2026, 1, 1), Time.new!(0, 0, 0))
    |> DateTime.add(i, :second)
    |> DateTime.to_iso8601()
  end
end
