defmodule Ex4pmEvidence.ConformanceTest do
  use ExUnit.Case, async: true

  alias Ex4pm.OCEL
  alias Ex4pmCore.ProcessIR
  alias Ex4pmEvidence.Conformance
  alias Ex4pmEvidence.Conformance.Vector

  @base_ocel %{
    "objects" => %{
      "order_1" => %{"type" => "Order"},
      "order_2" => %{"type" => "Order"}
    },
    "events" => %{
      "e1" => %{
        "activity" => "create_order",
        "timestamp" => "2026-01-01T08:00:00Z",
        "objects" => ["order_1"],
        "attributes" => %{"resource" => "alice", "lifecycle" => "complete"}
      },
      "e2" => %{
        "activity" => "approve_order",
        "timestamp" => "2026-01-01T09:00:00Z",
        "objects" => ["order_1"],
        "attributes" => %{"resource" => "bob", "lifecycle" => "complete"}
      },
      "e3" => %{
        "activity" => "ship_goods",
        "timestamp" => "2026-01-01T10:00:00Z",
        "objects" => ["order_1"],
        "attributes" => %{"resource" => "carol", "lifecycle" => "complete"}
      },
      # Order 2 has an SoD policy violation (alice approves her own order)
      "e4" => %{
        "activity" => "create_order",
        "timestamp" => "2026-01-01T08:30:00Z",
        "objects" => ["order_2"],
        "attributes" => %{"resource" => "alice", "lifecycle" => "complete"}
      },
      "e5" => %{
        "activity" => "approve_order",
        "timestamp" => "2026-01-01T09:30:00Z",
        "objects" => ["order_2"],
        "attributes" => %{"resource" => "alice", "lifecycle" => "complete"}
      },
      "e6" => %{
        "activity" => "ship_goods",
        "timestamp" => "2026-01-01T11:00:00Z",
        "objects" => ["order_2"],
        "attributes" => %{"resource" => "carol", "lifecycle" => "complete"}
      }
    }
  }

  test "computes 5-dimensional conformance vector with ProcessIR" do
    assert {:ok, log} = OCEL.normalize(@base_ocel)

    assert {:ok, ir} =
             ProcessIR.new(%{
               id: "order_process",
               activities: [
                 %{id: "create_order"},
                 %{id: "approve_order"},
                 %{id: "ship_goods"}
               ],
               partial_orders: [
                 %{
                   id: "po1",
                   nodes: ["create_order", "approve_order", "ship_goods"],
                   edges: [
                     {"create_order", "approve_order"},
                     {"approve_order", "ship_goods"}
                   ]
                 }
               ],
               policies: [
                 %{
                   id: "sod_creator_approver",
                   type: :sod,
                   target_activities: ["create_order", "approve_order"],
                   description: "Creator and approver must be distinct"
                 },
                 %{
                   id: "sla_fulfillment",
                   type: :sla,
                   target_activities: ["create_order", "ship_goods"],
                   rules: %{max_duration_hours: 5}
                 }
               ],
               objects: [%{id: "Order"}]
             })

    assert {:ok, %Vector{} = vec} = Conformance.evaluate(log, ir, object_type: "Order")

    assert vec.fitness == 1.0
    assert vec.precision >= 0.9

    # 2 cases evaluated for 2 policies: 1 SoD violation in order_2 -> 3 checks pass out of 4 -> 0.75
    assert vec.policy_conformance == 0.75
    assert vec.lifecycle_conformance == 1.0
    assert vec.causal_conformance == 1.0
    assert vec.standing == :alive
    assert String.starts_with?(vec.subject_hash, "sha256:")

    # Verify violation is recorded
    assert Enum.any?(vec.violations, fn v ->
             v.dimension == :policy and v.rule == :sod_violation and v.case_id == "order_2"
           end)
  end

  test "detects fitness deviations when log deviates from process model" do
    bad_ocel = %{
      "objects" => %{"o1" => %{"type" => "Order"}},
      "events" => %{
        "e1" => %{
          "activity" => "create_order",
          "timestamp" => "2026-01-01T08:00:00Z",
          "objects" => ["o1"]
        },
        "e2" => %{
          "activity" => "ship_goods",
          "timestamp" => "2026-01-01T09:00:00Z",
          "objects" => ["o1"]
        },
        "e3" => %{
          "activity" => "approve_order",
          "timestamp" => "2026-01-01T10:00:00Z",
          "objects" => ["o1"]
        }
      }
    }

    assert {:ok, log} = OCEL.normalize(bad_ocel)

    model = %{
      type: :dfg,
      edges: %{
        {"create_order", "approve_order"} => %{count: 1},
        {"approve_order", "ship_goods"} => %{count: 1}
      }
    }

    assert {:ok, %Vector{} = vec} = Conformance.evaluate(log, model, object_type: "Order")
    assert vec.fitness < 1.0
    assert Enum.any?(vec.violations, &(&1.dimension == :fitness))
  end

  test "detects causal order inversion" do
    inverted_ocel = %{
      "objects" => %{"o1" => %{"type" => "Order"}},
      "events" => %{
        "e1" => %{
          "activity" => "ship_goods",
          "timestamp" => "2026-01-01T08:00:00Z",
          "objects" => ["o1"]
        },
        "e2" => %{
          "activity" => "create_order",
          "timestamp" => "2026-01-01T09:00:00Z",
          "objects" => ["o1"]
        }
      }
    }

    assert {:ok, log} = OCEL.normalize(inverted_ocel)

    assert {:ok, %Vector{} = vec} =
             Conformance.evaluate(log, %{},
               object_type: "Order",
               causal_dependencies: [{"create_order", "ship_goods"}]
             )

    assert vec.causal_conformance == 0.0

    assert Enum.any?(vec.violations, fn v ->
             v.dimension == :causal and v.rule == :causal_inversion
           end)
  end

  test "detects lifecycle state machine violations" do
    lifecycle_ocel = %{
      "objects" => %{"o1" => %{"type" => "Order"}},
      "events" => %{
        # Invalid lifecycle transition: complete before start
        "e1" => %{
          "activity" => "process_payment",
          "timestamp" => "2026-01-01T08:00:00Z",
          "objects" => ["o1"],
          "attributes" => %{"lifecycle" => "complete"}
        },
        "e2" => %{
          "activity" => "process_payment",
          "timestamp" => "2026-01-01T09:00:00Z",
          "objects" => ["o1"],
          "attributes" => %{"lifecycle" => "start"}
        }
      }
    }

    assert {:ok, log} = OCEL.normalize(lifecycle_ocel)
    assert {:ok, %Vector{} = vec} = Conformance.evaluate(log, %{}, object_type: "Order")
    assert vec.lifecycle_conformance < 1.0

    assert Enum.any?(vec.violations, fn v ->
             v.dimension == :lifecycle and v.rule == :invalid_lifecycle_transition
           end)
  end
end
