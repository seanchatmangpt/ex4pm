# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Beamops.BookValidationReactorTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Reactors.BEAMOps.BookValidationReactor

  describe "Engineering Elixir Applications - Process Intelligence Validation Reactor" do
    test "Validates all 12 stages with 100% trace alignment, Declare LTLf compliance, Bayesian confidence, and BRCE receipts" do
      inputs = %{
        tool_versions: %{erlang: "27.2.4", elixir: "1.18.4"},
        milestones: ["v1.0-mvp", "v2.0-swarm"],
        issues: ["issue_01_docker", "issue_02_ci", "issue_03_telemetry"],
        docker_stages: [:builder, :releaser, :runner],
        non_root_user: "nobody",
        ci_steps: [:format, :compile, :test, :docker_push],
        compose_services: [:db, :app, :prometheus],
        vpc_config: %{subnets: ["subnet_a", "subnet_b"], security_group: "sg_beamops"},
        encrypted_payload: %{sops: %{version: "3.8.1"}, data: "encrypted_blob"},
        recipient_key: "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p",
        swarm_nodes: ["ec2-node-1", "ec2-node-2", "ec2-node-3"],
        overlay_network: "kanban_overlay_net",
        cluster_strategy: :gossip,
        connected_nodes: ["node1@127.0.0.1", "node2@127.0.0.1"],
        asg_config: %{min_size: 2, max_size: 6},
        alb_probes: ["/healthz", "/readyz"],
        logger_format: :json,
        promtail_config: %{targets: ["/var/log/kanban.json"]},
        promex_plugins: [:cpu_plugin, :phoenix, :ecto],
        alert_rules: ["high_cpu_alert", "endpoint_5xx_alert"]
      }

      {:ok, bundle} =
        Reactor.run(BookValidationReactor, inputs, %{}, async?: false)

      assert bundle.stages_validated == 12
      assert bundle.alignment_fitness == 1.0
      assert bundle.conformance_verdict == :fully_conformant
      assert is_binary(bundle.receipt_hash)
      assert bundle.standing == :alive
      assert bundle.replay_match? == true

      # Verify persisted canonical BRCE receipt in Ex4pm.Evidence.Store
      {:ok, receipt} = Ex4pm.Evidence.Store.get(bundle.receipt_hash)
      assert receipt.operation == "book_curriculum_validation"
      assert receipt.standing == :alive
      assert receipt.metadata[:fitness] == 1.0
      assert {:ok, _} = Ex4pm.Evidence.Replay.verify(receipt)
    end
  end
end
