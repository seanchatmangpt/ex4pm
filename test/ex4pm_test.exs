defmodule Ex4pmTest do
  use ExUnit.Case, async: false

  @raw %{
    "objects" => %{
      "o1" => %{"type" => "Order"},
      "o2" => %{"type" => "Order"}
    },
    "events" => %{
      "e1" => %{
        "activity" => "create",
        "timestamp" => "2026-01-01T00:00:00Z",
        "objects" => ["o1"]
      },
      "e2" => %{
        "activity" => "ship",
        "timestamp" => "2026-01-01T00:01:00Z",
        "objects" => ["o1"]
      },
      "e3" => %{
        "activity" => "create",
        "timestamp" => "2026-01-01T00:02:00Z",
        "objects" => ["o2"]
      },
      "e4" => %{
        "activity" => "ship",
        "timestamp" => "2026-01-01T00:04:00Z",
        "objects" => ["o2"]
      }
    }
  }

  test "end-to-end analytical routes manufacture replayable receipts" do
    assert {:ok, log} = Ex4pm.ingest(@raw)
    assert {:ok, discovery} = Ex4pm.discover(log, object_type: "Order")
    assert discovery.standing == :alive
    assert {:ok, %{replay: :chain_match}} = Ex4pm.replay(discovery.receipt.hash)

    assert {:ok, conformance} = Ex4pm.conform(log, discovery.value, object_type: "Order")
    assert conformance.value.fitness == 1.0

    assert {:ok, simulation} = Ex4pm.simulate(discovery.value)
    assert simulation.value.paths == [["create", "ship"]]

    assert {:ok, optimization} = Ex4pm.optimize(log, discovery.value)
    assert [%{mode: :construct_only} | _] = optimization.value.candidates
  end

  test "Ash projection is explicit and does not replace the canonical log" do
    assert {:ok, log} = Ex4pm.ingest(@raw, project?: true)
    assert [_projection] = log.metadata.projections
    assert %Ex4pm.EventLog{} = log

    assert {:ok, run} = Ex4pm.discover(log, object_type: "Order", project?: true)
    assert length(run.projections) == 2
  end

  test "operate refuses absent authority and succeeds with explicit DO capability" do
    assert {:ok, model} = Ex4pm.POWL.new([%{id: "a"}, %{id: "b"}], [{"a", "b"}])

    assert {:error, %{failure: %Ex4pm.Refusal{code: :authority_required}}} =
             Ex4pm.operate(model, nil)

    assert {:ok, %{standing: :alive, execution: execution}} =
             Ex4pm.operate(model, %{id: "operator", capabilities: [:do]})

    assert length(execution.receipt_hashes) == 2
  end

  test "public contract surface closes ontology, SHACL, WIT, and receipt schema" do
    assert {:ok, contract} = Ex4pm.contracts()
    assert contract.standing == :alive
    assert map_size(contract.artifacts) == 4
  end

  describe "ingest/2 against the real committed marketplace-ocel.json fixture" do
    # Regression for a real, reproducible bug: OCEL 2.0's own spec allows an
    # event's/object's "attributes" to be a plain map OR a list of
    # {name, value} pair-maps (the shape test/fixtures/marketplace-ocel.json
    # actually uses). Ex4pm.OCEL.drop_known_event_keys/1 and
    # drop_known_object_keys/1 only handled the map shape, so a direct
    # Ex4pm.ingest/2 call on this real fixture raised an unhandled
    # BadMapError (events) and silently double-nested attributes (objects)
    # instead of returning {:ok, log} or a typed {:error, %Refusal{}} --
    # violating the documented "never raise" ingestion contract
    # (docs/consumer/tutorials.md).
    test "ingests real events and flattens explicit list-shaped attributes, never raises" do
      fixture_path = Path.join([__DIR__, "fixtures", "marketplace-ocel.json"])
      {:ok, bytes} = File.read(fixture_path)
      {:ok, raw} = Jason.decode(bytes)

      assert {:ok, log} = Ex4pm.ingest(raw, [])
      assert length(log.events) > 0
      assert map_size(log.objects) > 0

      # e1 in the fixture carries attributes: [%{"name" => "channel", "value" => "web"}]
      event = Enum.find(log.events, &(&1.id == "e1"))
      assert event.attributes == %{"channel" => "web"}

      # order-001 in the fixture carries attributes: {"currency": "USD", "value": 150.0}
      # (object-side attributes fixture happens to already be a map -- the
      # object-side bug this regression also covers was double-nesting,
      # asserted below via a synthetic list-shaped object).
      object = Map.get(log.objects, "order-001")
      assert object.attributes == %{"currency" => "USD", "value" => 150.0}
    end

    test "flattens a synthetic object whose explicit attributes are list-shaped, not double-nested" do
      raw = %{
        "objects" => [
          %{
            "id" => "o1",
            "type" => "Order",
            "attributes" => [%{"name" => "priority", "value" => "high"}]
          }
        ],
        "events" => []
      }

      assert {:ok, log} = Ex4pm.ingest(raw, [])
      object = Map.get(log.objects, "o1")
      assert object.attributes == %{"priority" => "high"}
      refute Map.has_key?(object.attributes, "attributes")
    end
  end
end
