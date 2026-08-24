# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Beamops.RollingDeploymentSagaTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Reactors.BEAMOps.RollingDeploymentReactor
  alias Ex4pmDomain.BEAMOps.Deployment

  describe "RollingDeploymentReactor Saga Execution" do
    test "Happy Path: Rolling deployment across 3 Swarm nodes succeeds with health probes" do
      dep_id = "dep_happy_#{System.unique_integer([:positive])}"
      nodes = ["node1", "node2", "node3"]

      {:ok, result} =
        Reactor.run(
          RollingDeploymentReactor,
          %{
            deployment_id: dep_id,
            version: "26.8.23",
            image_digest: "sha256:542cef896dd1a9",
            nodes: nodes,
            inject_fault?: false,
            fault_node: nil
          },
          %{test_pid: self()},
          async?: false
        )

      assert result.deployment_id == dep_id
      assert result.version == "26.8.23"
      assert result.status == :healthy
      assert result.probes_passed == 3
      assert result.standing == :alive

      # Verify messages received in order
      assert_received {:deployment_reserved, ^dep_id, "26.8.23"}
      assert_received {:node_release_staged, "node1", "26.8.23"}
      assert_received {:node_release_staged, "node2", "26.8.23"}
      assert_received {:node_release_staged, "node3", "26.8.23"}
      assert_received {:deployment_promoted, ^dep_id}

      # Verify persisted Ash state
      {:ok, persisted} = Ash.get(Deployment, dep_id)
      assert persisted.status == :healthy
      assert persisted.health_probes_passed == 3
    end

    test "Adversarial Fault Injection: Health probe failure on node2 triggers strict reverse LIFO rollback" do
      dep_id = "dep_fault_#{System.unique_integer([:positive])}"
      nodes = ["node1", "node2", "node3"]

      assert {:error, _errors} =
               Reactor.run(
                 RollingDeploymentReactor,
                 %{
                   deployment_id: dep_id,
                   version: "26.8.23-bad",
                   image_digest: "sha256:bad000000",
                   nodes: nodes,
                   inject_fault?: true,
                   fault_node: "node2"
                 },
                 %{test_pid: self()},
                 async?: false
               )

      # Verify reverse LIFO rollback messages
      assert_received {:deployment_reserved, ^dep_id, "26.8.23-bad"}
      assert_received {:node_release_staged, "node1", "26.8.23-bad"}
      assert_received {:node_release_staged, "node2", "26.8.23-bad"}
      assert_received {:node_release_staged, "node3", "26.8.23-bad"}

      # Compensation execution in reverse order
      assert_received {:node_release_reverted, "node3"}
      assert_received {:node_release_reverted, "node2"}
      assert_received {:node_release_reverted, "node1"}
      assert_received {:deployment_undone, ^dep_id}

      # Verify persisted Ash state reflects rollback
      {:ok, persisted} = Ash.get(Deployment, dep_id)
      assert persisted.status == :rolled_back
    end
  end
end
