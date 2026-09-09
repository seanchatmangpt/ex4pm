defmodule Ex4pmCore.ProcessIRTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR
  alias Ex4pm.Refusal

  test "creates and validates a canonical ProcessIR with all constructs" do
    attrs = %{
      id: "proc_order_to_cash",
      name: "Order to Cash",
      version: "2.1.0",
      activities: [
        %{
          id: "create_order",
          label: "Create Order",
          object_types: ["Order"],
          lifecycle_states: ["create"]
        },
        %{id: "check_credit", label: "Check Credit", object_types: ["Order", "Customer"]},
        %{id: "approve_order", label: "Approve Order", object_types: ["Order"]},
        %{id: "reject_order", label: "Reject Order", object_types: ["Order"]},
        %{id: "ship_goods", label: "Ship Goods", object_types: ["Order", "Package"]},
        %{id: "issue_invoice", label: "Issue Invoice", object_types: ["Invoice"]},
        %{id: "receive_payment", label: "Receive Payment", object_types: ["Payment"]},
        %{id: "retry_payment", label: "Retry Payment", object_types: ["Payment"]}
      ],
      choices: [
        %{
          id: "credit_decision",
          type: :xor,
          branches: ["approve_order", "reject_order"],
          default_branch: "approve_order"
        }
      ],
      loops: [
        %{
          id: "payment_loop",
          body: "receive_payment",
          redo: "retry_payment",
          max_iterations: 3
        }
      ],
      partial_orders: [
        %{
          id: "fulfillment_po",
          nodes: ["approve_order", "ship_goods", "issue_invoice"],
          edges: [
            {"approve_order", "ship_goods"},
            {"approve_order", "issue_invoice"}
          ]
        }
      ],
      guards: [
        %{
          id: "high_value_guard",
          expression: %{field: "total_amount", op: ">", value: 10_000},
          description: "Order total exceeds $10,000"
        }
      ],
      policies: [
        %{
          id: "sod_approval_payment",
          type: :sod,
          target_activities: ["approve_order", "receive_payment"],
          rules: %{distinct_performers: true},
          description: "Approver cannot receive payment"
        },
        %{
          id: "sla_fulfillment",
          type: :sla,
          target_activities: ["create_order", "ship_goods"],
          rules: %{max_duration_hours: 48}
        }
      ],
      objects: [
        %{id: "Order", name: "Sales Order", cardinality: :one},
        %{id: "Customer", name: "Customer", cardinality: :one},
        %{id: "Invoice", name: "Commercial Invoice", cardinality: :one},
        %{id: "Payment", name: "Payment Receipt", cardinality: :many},
        %{id: "Package", name: "Shipping Package", cardinality: :many}
      ],
      relationships: [
        %{
          id: "order_to_customer",
          source: "Order",
          target: "Customer",
          type: :o2o,
          qualifier: "placed_by"
        },
        %{
          id: "order_to_invoice",
          source: "Order",
          target: "Invoice",
          type: :o2o,
          qualifier: "billed_as"
        },
        %{
          id: "order_to_payment",
          source: "Order",
          target: "Payment",
          type: :o2m,
          qualifier: "settled_by"
        }
      ]
    }

    assert {:ok, ir} = ProcessIR.new(attrs)
    assert ir.id == "proc_order_to_cash"
    assert map_size(ir.activities) == 8
    assert map_size(ir.choices) == 1
    assert map_size(ir.loops) == 1
    assert map_size(ir.partial_orders) == 1
    assert map_size(ir.policies) == 2
    assert map_size(ir.objects) == 5
    assert map_size(ir.relationships) == 3
    assert ir.subject.kind == :process_ir
    assert String.starts_with?(ir.subject.hash, "sha256:")
  end

  test "refuses cyclic partial order" do
    attrs = %{
      id: "cyclic_proc",
      activities: [%{id: "a"}, %{id: "b"}],
      partial_orders: [
        %{id: "po1", nodes: ["a", "b"], edges: [{"a", "b"}, {"b", "a"}]}
      ]
    }

    assert {:error, %Refusal{code: :cyclic_partial_order}} = ProcessIR.new(attrs)
  end

  test "refuses unknown policy targets" do
    attrs = %{
      id: "invalid_pol_proc",
      activities: [%{id: "a"}],
      policies: [
        %{id: "pol1", type: :sod, target_activities: ["a", "non_existent"]}
      ]
    }

    assert {:error, %Refusal{code: :invalid_policy_target}} = ProcessIR.new(attrs)
  end

  test "refuses unknown loop body" do
    attrs = %{
      id: "invalid_loop_proc",
      activities: [%{id: "a"}],
      loops: [
        %{id: "loop1", body: "unknown_act", redo: "a"}
      ]
    }

    assert {:error, %Refusal{code: :invalid_loop_body}} = ProcessIR.new(attrs)
  end

  test "refuses unknown relationship object types" do
    attrs = %{
      id: "invalid_rel_proc",
      objects: [%{id: "Order"}],
      relationships: [
        %{id: "rel1", source: "Order", target: "NonExistent", type: :o2o}
      ]
    }

    assert {:error, %Refusal{code: :invalid_relationship_object}} = ProcessIR.new(attrs)
  end
end
