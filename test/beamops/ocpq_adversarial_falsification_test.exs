# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Beamops.OcpqAdversarialFalsificationTest do
  use ExUnit.Case, async: true

  alias Ex4pm.{Event, EventLog, ObjectRef, ObjectRelationship, Subject}
  alias Ex4pmEngine.Cognition.Ocpq.{BindingBox, QueryTree, VarDecl}
  alias Ex4pmEngine.Reactors.BEAMOps.OcpqAdversarialReactor

  setup do
    # Multi-object log representing living cluster deployment & monitoring traces
    # Object Types: Deployment, ClusterNode, KanbanCard, MetricProbe
    log = %EventLog{
      events: [
        %Event{
          id: "ev_start_deploy",
          activity: "deploy_started",
          timestamp: "2026-08-24T03:30:00Z",
          object_ids: ["dep_01", "card_10"],
          relationships: [
            %{"objectId" => "dep_01", "qualifier" => "target_deployment"},
            %{"objectId" => "card_10", "qualifier" => "source_task"}
          ]
        },
        %Event{
          id: "ev_node_1_join",
          activity: "cluster_node_joined",
          timestamp: "2026-08-24T03:30:02Z",
          object_ids: ["node_worker1", "dep_01"],
          relationships: [
            %{"objectId" => "node_worker1", "qualifier" => "joined_node"},
            %{"objectId" => "dep_01", "qualifier" => "parent_deployment"}
          ]
        },
        %Event{
          id: "ev_node_2_join",
          activity: "cluster_node_joined",
          timestamp: "2026-08-24T03:30:03Z",
          object_ids: ["node_worker2", "dep_01"],
          relationships: [
            %{"objectId" => "node_worker2", "qualifier" => "joined_node"},
            %{"objectId" => "dep_01", "qualifier" => "parent_deployment"}
          ]
        },
        %Event{
          id: "ev_probe_cpu",
          activity: "metric_sampled",
          timestamp: "2026-08-24T03:30:05Z",
          object_ids: ["probe_cpu_01", "node_worker1"],
          relationships: [
            %{"objectId" => "probe_cpu_01", "qualifier" => "sampled_probe"},
            %{"objectId" => "node_worker1", "qualifier" => "target_node"}
          ]
        }
      ],
      objects: %{
        "dep_01" => %ObjectRef{id: "dep_01", type: "Deployment"},
        "card_10" => %ObjectRef{id: "card_10", type: "KanbanCard"},
        "node_worker1" => %ObjectRef{id: "node_worker1", type: "ClusterNode"},
        "node_worker2" => %ObjectRef{id: "node_worker2", type: "ClusterNode"},
        "probe_cpu_01" => %ObjectRef{id: "probe_cpu_01", type: "MetricProbe"}
      },
      object_relationships: [
        %ObjectRelationship{source_id: "dep_01", target_id: "card_10", qualifier: "implements"},
        %ObjectRelationship{source_id: "node_worker1", target_id: "dep_01", qualifier: "hosts"},
        %ObjectRelationship{source_id: "node_worker2", target_id: "dep_01", qualifier: "hosts"}
      ],
      subject: %Subject{kind: :event_log, hash: "beamops_ocpq_trace_01"}
    }

    %{log: log}
  end

  describe "Multi-Object Process Invariants" do
    test "Evaluates multi-object E2O, O2O and TBE predicates with Reactor & seals receipt", %{
      log: log
    } do
      # Query: Find deployment (d) linked to card (c) with start event (e1),
      # and child cluster node join event (e2) within 5,000 ms
      query_tree = %QueryTree{
        root_box: %BindingBox{
          vars: [
            %VarDecl{name: "e1", kind: :event, types: ["deploy_started"]},
            %VarDecl{name: "d", kind: :object, types: ["Deployment"]},
            %VarDecl{name: "c", kind: :object, types: ["KanbanCard"]}
          ],
          predicates: [
            {:e2o, "e1", "d", "target_deployment"},
            {:e2o, "e1", "c", "source_task"},
            {:o2o, "d", "c", "implements"}
          ]
        },
        children: [
          %QueryTree{
            root_box: %BindingBox{
              vars: [
                %VarDecl{name: "e2", kind: :event, types: ["cluster_node_joined"]},
                %VarDecl{name: "n", kind: :object, types: ["ClusterNode"]}
              ],
              predicates: [
                {:e2o, "e2", "n", "joined_node"},
                {:o2o, "n", "d", "hosts"},
                {:tbe, "e1", "e2", :<=, 5000}
              ]
            },
            min_children: 2,
            max_children: 2
          }
        ]
      }

      {:ok, bundle} =
        Reactor.run(
          OcpqAdversarialReactor,
          %{event_log: log, query_tree: query_tree, expected_cardinality: %{min: 1, max: 1}},
          %{},
          async?: false
        )

      assert bundle.ocpq_status == :satisfied
      assert bundle.bindings_found == 1
      assert bundle.standing == :alive
      assert is_binary(bundle.receipt_hash)
      assert bundle.replay_match? == true

      # Verify sealed canonical BRCE receipt in Ex4pm.Evidence.Store
      {:ok, receipt} = Ex4pm.Evidence.Store.get(bundle.receipt_hash)
      assert receipt.operation == "ocpq_multi_object_validation"
      assert receipt.standing == :alive
      assert receipt.metadata[:bindings_count] == 1
      assert {:ok, _} = Ex4pm.Evidence.Replay.verify(receipt)
    end
  end

  describe "Adversarial Falsification Attacks" do
    test "Falsifies Time Between Events (TBE) latency violation (adversarial SLA breach)", %{
      log: log
    } do
      # Adversarial Query demanding join within 1000ms (actual is 2000ms & 3000ms)
      strict_sla_tree = %QueryTree{
        root_box: %BindingBox{
          vars: [
            %VarDecl{name: "e1", kind: :event, types: ["deploy_started"]},
            %VarDecl{name: "d", kind: :object, types: ["Deployment"]}
          ],
          predicates: [{:e2o, "e1", "d", "target_deployment"}]
        },
        children: [
          %QueryTree{
            root_box: %BindingBox{
              vars: [
                %VarDecl{name: "e2", kind: :event, types: ["cluster_node_joined"]},
                %VarDecl{name: "n", kind: :object, types: ["ClusterNode"]}
              ],
              predicates: [
                {:e2o, "e2", "n", "joined_node"},
                # Adversarially strict SLA: 1000ms limit (must fail to match)
                {:tbe, "e1", "e2", :<=, 1000}
              ]
            },
            min_children: 2,
            max_children: :infinity
          }
        ]
      }

      result =
        Reactor.run(
          OcpqAdversarialReactor,
          %{event_log: log, query_tree: strict_sla_tree, expected_cardinality: %{min: 1, max: 1}},
          %{},
          async?: false
        )

      assert {:error, %Reactor.Error.Invalid{errors: [err]}} = result
      assert err.error == {:ocpq_cardinality_violation, %{expected: {1, 1}, found: 0}}
    end

    test "Falsifies Non-Existent Multi-Object Graph Link (Adversarial Fake Edge)", %{log: log} do
      # Adversarially query a non-existent O2O edge (MetricProbe claims to host Deployment)
      fake_graph_tree = %QueryTree{
        root_box: %BindingBox{
          vars: [
            %VarDecl{name: "p", kind: :object, types: ["MetricProbe"]},
            %VarDecl{name: "d", kind: :object, types: ["Deployment"]}
          ],
          predicates: [
            # Fake edge that doesn't exist
            {:o2o, "p", "d", "unauthorized_host"}
          ]
        }
      }

      result =
        Reactor.run(
          OcpqAdversarialReactor,
          %{event_log: log, query_tree: fake_graph_tree, expected_cardinality: %{min: 1, max: 1}},
          %{},
          async?: false
        )

      assert {:error, %Reactor.Error.Invalid{errors: [err]}} = result
      assert err.error == {:ocpq_cardinality_violation, %{expected: {1, 1}, found: 0}}
    end

    test "Falsifies Cardinality Bound Attack (Attempting to assert solitary node when cluster is multi-node)",
         %{log: log} do
      # Assert only max 1 child node allowed, when deployment actually joined 2 nodes
      max_one_child_tree = %QueryTree{
        root_box: %BindingBox{
          vars: [
            %VarDecl{name: "e1", kind: :event, types: ["deploy_started"]},
            %VarDecl{name: "d", kind: :object, types: ["Deployment"]}
          ],
          predicates: [{:e2o, "e1", "d", "target_deployment"}]
        },
        children: [
          %QueryTree{
            root_box: %BindingBox{
              vars: [
                %VarDecl{name: "e2", kind: :event, types: ["cluster_node_joined"]},
                %VarDecl{name: "n", kind: :object, types: ["ClusterNode"]}
              ],
              predicates: [{:e2o, "e2", "n", "joined_node"}]
            },
            min_children: 1,
            # Strict max 1 child node: will reject the 2-node deployment
            max_children: 1
          }
        ]
      }

      result =
        Reactor.run(
          OcpqAdversarialReactor,
          %{
            event_log: log,
            query_tree: max_one_child_tree,
            expected_cardinality: %{min: 1, max: 1}
          },
          %{},
          async?: false
        )

      assert {:error, %Reactor.Error.Invalid{errors: [err]}} = result
      assert err.error == {:ocpq_cardinality_violation, %{expected: {1, 1}, found: 0}}
    end
  end
end
