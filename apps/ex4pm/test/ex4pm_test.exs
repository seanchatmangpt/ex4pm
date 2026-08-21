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
    assert {:ok, %{replay: :match}} = Ex4pm.replay(discovery.receipt.hash)

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
end
