defmodule Ex4pm.EngineTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Engine

  @ocel %{
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
        "activity" => "approve",
        "timestamp" => "2026-01-01T00:01:00Z",
        "objects" => ["o1"]
      },
      "e3" => %{
        "activity" => "create",
        "timestamp" => "2026-01-01T00:02:00Z",
        "objects" => ["o2"]
      },
      "e4" => %{
        "activity" => "reject",
        "timestamp" => "2026-01-01T00:03:00Z",
        "objects" => ["o2"]
      }
    }
  }

  test "BEAM DFG discovery, conformance, simulation, and optimization execute" do
    assert {:ok, log} = Ex4pm.OCEL.normalize(@ocel)

    assert {:ok, discovery} =
             Engine.execute(:discover, log, algorithm: :dfg, object_type: "Order")

    assert discovery.standing == :alive
    assert discovery.value.edges[{"create", "approve"}].count == 1
    assert discovery.value.edges[{"create", "reject"}].count == 1

    assert {:ok, conformance} =
             Engine.execute(:conform, {log, discovery.value}, object_type: "Order")

    assert conformance.value.fitness == 1.0

    assert {:ok, simulation} = Engine.execute(:simulate, discovery.value, max_depth: 5)
    assert ["create", "approve"] in simulation.value.paths
    assert ["create", "reject"] in simulation.value.paths

    assert {:ok, optimization} = Engine.execute(:optimize, {log, discovery.value})
    assert optimization.value.candidates != []
    assert Enum.all?(optimization.value.candidates, &(&1.mode == :construct_only))
  end

  test "registry preserves blocked and unsupported engine candidates" do
    candidates = Engine.candidates(:discover)
    assert Enum.map(candidates, & &1.id) == [:beam, :wasm, :nif, :remote]
    assert Enum.find(candidates, &(&1.id == :beam)).standing == :alive
    assert Enum.find(candidates, &(&1.id == :wasm)).standing == :unsupported
  end
end
