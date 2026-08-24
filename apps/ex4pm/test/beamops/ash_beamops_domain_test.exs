# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Beamops.AshBeamopsDomainTest do
  use ExUnit.Case, async: true

  alias Ex4pmDomain.BEAMOps.{KanbanCard, ClusterNode, Deployment, MetricProbe}

  describe "BEAMOps Ash Resources & Public Ontology Parity" do
    test "KanbanCard lifecycle: backlog -> in_progress -> review -> done" do
      card_id = "card_#{System.unique_integer([:positive])}"

      {:ok, card} =
        Ash.create(KanbanCard, %{
          id: card_id,
          title: "Implement BEAMOps Telemetry",
          description: "Chapter 12 PromEx Alert Rules",
          column: :backlog,
          priority: :high,
          assigned_agent: "agent_beamops_01"
        })

      assert card.id == card_id
      assert card.column == :backlog
      assert card.ontology_class == "beamops:KanbanCard"

      # Move column
      {:ok, in_prog} = Ash.update(card, %{column: :in_progress}, action: :move_column)
      assert in_prog.column == :in_progress

      {:ok, done} = Ash.update(in_prog, %{column: :done}, action: :move_column)
      assert done.column == :done
    end

    test "ClusterNode registration & heartbeat" do
      node_id = "node_#{System.unique_integer([:positive])}"

      {:ok, node} =
        Ash.create(ClusterNode, %{
          id: node_id,
          node_name: "node1@ec2-prod-swarm.internal",
          ip_address: "10.0.1.42",
          port: 4369,
          status: :healthy,
          node_type: :primary,
          heartbeat_at: "2026-08-23T20:00:00Z"
        })

      assert node.node_type == :primary
      assert node.ontology_class == "beamops:ClusterNode"

      {:ok, updated} =
        Ash.update(
          node,
          %{
            heartbeat_at: "2026-08-23T20:01:00Z",
            status: :healthy
          },
          action: :heartbeat
        )

      assert updated.heartbeat_at == "2026-08-23T20:01:00Z"
    end

    test "Deployment creation and rollback action" do
      dep_id = "dep_#{System.unique_integer([:positive])}"

      {:ok, dep} =
        Ash.create(Deployment, %{
          id: dep_id,
          version: "26.8.23",
          image_digest: "sha256:abcd1234ef5678",
          target_nodes: ["node1", "node2"],
          status: :rolling_out
        })

      assert dep.status == :rolling_out
      assert dep.ontology_class == "beamops:Deployment"

      {:ok, rolled_back} =
        Ash.update(
          dep,
          %{
            status: :rolled_back,
            rollback_version: "26.8.22"
          },
          action: :rollback
        )

      assert rolled_back.status == :rolled_back
      assert rolled_back.rollback_version == "26.8.22"
    end

    test "MetricProbe sampling and alert evaluation" do
      probe_id = "probe_#{System.unique_integer([:positive])}"

      {:ok, probe} =
        Ash.create(MetricProbe, %{
          id: probe_id,
          name: "beam.system.cpu_utilization",
          category: :beam,
          value: 94.5,
          labels: %{"instance" => "node1", "service" => "kanban"},
          alert_state: :alerting
        })

      assert probe.category == :beam
      assert probe.value == 94.5
      assert probe.alert_state == :alerting
      assert probe.ontology_class == "beamops:MetricProbe"
    end
  end
end
