# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Beamops.ClusterOrchestrationTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Reactors.BEAMOps.{ClusterRebalanceReactor, PromExAuditReactor}
  alias Ex4pmDomain.BEAMOps.ClusterNode

  describe "ClusterRebalanceReactor & PromExAuditReactor" do
    test "ClusterRebalanceReactor reconciles joining and leaving nodes" do
      target_nodes = ["swarm_node1", "swarm_node2", "swarm_node3"]
      active_peers = ["swarm_node1", "swarm_node_old"]

      {:ok, result} =
        Reactor.run(
          ClusterRebalanceReactor,
          %{
            target_nodes: target_nodes,
            active_peers: active_peers
          },
          %{},
          async?: false
        )

      assert result.cluster_size == 3
      assert result.active_nodes == target_nodes
      assert result.joined_count == 2
      assert result.left_count == 1
      assert result.standing == :alive

      # Verify joined nodes are in Ash
      {:ok, node2} = Ash.get(ClusterNode, "node_swarm_node2")
      assert node2.status == :healthy
      assert node2.node_name == "swarm_node2@127.0.0.1"
    end

    test "PromExAuditReactor samples probes and detects alerts" do
      healthy_samples = [
        %{name: "phoenix.endpoint.stop.duration", value: 12.4, category: :phoenix},
        %{name: "beam.system.cpu", value: 35.0, category: :beam},
        %{name: "kanban.work_in_progress.count", value: 45.0, category: :custom}
      ]

      # Scenario 1: Healthy (all under threshold 50.0)
      {:ok, healthy_summary} =
        Reactor.run(
          PromExAuditReactor,
          %{
            metric_samples: healthy_samples,
            alert_threshold: 50.0
          },
          %{},
          async?: false
        )

      assert healthy_summary.total_probes_sampled == 3
      assert healthy_summary.alert_count == 0
      assert healthy_summary.standing == :healthy

      # Scenario 2: Alerting on high CPU / memory (> 50.0)
      alerting_samples = [
        %{name: "phoenix.endpoint.stop.duration", value: 12.4, category: :phoenix},
        %{name: "beam.system.cpu", value: 92.5, category: :beam},
        %{name: "kanban.work_in_progress.count", value: 45.0, category: :custom}
      ]

      {:ok, alert_summary} =
        Reactor.run(
          PromExAuditReactor,
          %{
            metric_samples: alerting_samples,
            alert_threshold: 50.0
          },
          %{},
          async?: false
        )

      assert alert_summary.total_probes_sampled == 3
      assert alert_summary.alert_count == 1
      assert alert_summary.alerting_probes == ["beam.system.cpu"]
      assert alert_summary.standing == :degraded
    end
  end
end
