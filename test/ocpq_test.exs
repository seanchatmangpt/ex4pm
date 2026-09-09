defmodule Ex4pm.Engine.OcpqTest do
  use ExUnit.Case, async: true

  alias Ex4pm.{Event, EventLog, ObjectRef, Subject}
  alias Ex4pmEngine.Cognition.Ocpq
  alias Ex4pmEngine.Cognition.Ocpq.{BindingBox, QueryTree, VarDecl}

  test "OCPQ evaluates multi-object binding boxes and E2O/O2O predicates" do
    log = %EventLog{
      events: [
        %Event{
          id: "ev1",
          activity: "place_order",
          timestamp: "2026-08-21T10:00:00Z",
          object_ids: ["order_1", "item_1"],
          relationships: [%{"objectId" => "order_1", "qualifier" => "order"}]
        },
        %Event{
          id: "ev2",
          activity: "ship_package",
          timestamp: "2026-08-21T10:30:00Z",
          object_ids: ["pkg_1", "item_1"],
          relationships: [%{"objectId" => "pkg_1", "qualifier" => "package"}]
        }
      ],
      objects: %{
        "order_1" => %ObjectRef{id: "order_1", type: "Order"},
        "item_1" => %ObjectRef{id: "item_1", type: "Item"},
        "pkg_1" => %ObjectRef{id: "pkg_1", type: "Package"}
      },
      object_relationships: [
        %Ex4pm.ObjectRelationship{
          source_id: "order_1",
          target_id: "pkg_1",
          qualifier: "fulfilled_by"
        }
      ],
      subject: %Subject{kind: :event_log, hash: "ocpq_hash_1"}
    }

    # Query: Find all orders (o) with an event (e1 = place_order)
    # and a child package (p) with event (e2 = ship_package) shipped within 60 minutes
    query_tree = %QueryTree{
      root_box: %BindingBox{
        vars: [
          %VarDecl{name: "e1", kind: :event, types: ["place_order"]},
          %VarDecl{name: "o", kind: :object, types: ["Order"]}
        ],
        predicates: [
          {:e2o, "e1", "o", nil}
        ]
      },
      children: [
        %QueryTree{
          root_box: %BindingBox{
            vars: [
              %VarDecl{name: "e2", kind: :event, types: ["ship_package"]},
              %VarDecl{name: "p", kind: :object, types: ["Package"]}
            ],
            predicates: [
              {:e2o, "e2", "p", nil},
              {:o2o, "o", "p", "fulfilled_by"},
              {:tbe, "e1", "e2", :<=, 3_600_000}
            ]
          },
          min_children: 1,
          max_children: 1
        }
      ]
    }

    res = Ocpq.evaluate_query(log, query_tree)
    assert res.satisfied? == true
    assert res.total_root_bindings == 1
    assert res.violations_count == 0
  end
end
