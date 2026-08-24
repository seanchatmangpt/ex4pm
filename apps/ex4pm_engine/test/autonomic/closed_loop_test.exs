# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Autonomic.ClosedLoopTest do
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Autonomic.ClosedLoop
  alias Ex4pm.Evidence.Store

  setup do
    # Start an isolated instance of ClosedLoop for testing
    {:ok, pid} = ClosedLoop.start_link(name: :test_closed_loop, interval_ms: 10_000)
    %{pid: pid}
  end

  describe "Closed-Loop Autonomic MAPK Loop" do
    test "initializes in autonomous mode and monitoring phase" do
      {:ok, status} = ClosedLoop.get_status(:test_closed_loop)
      assert status.mode == :autonomous
      assert status.phase == :monitoring
      assert status.cycle_count == 0
    end

    test "executes autonomous MAPK cycles (Monitor -> Analyze -> Plan -> Execute) and mints receipts" do
      # Cycle 0: Book Curriculum Audit
      {:ok, action1} = ClosedLoop.trigger_cycle(:test_closed_loop)
      assert action1.type == :book_curriculum_audit
      assert action1.status == :success
      assert is_binary(action1.receipt_hash)

      # Verify receipt persisted in Store
      {:ok, receipt1} = Store.get(action1.receipt_hash)
      assert receipt1.operation == "book_curriculum_validation"
      assert receipt1.standing == :alive

      # Cycle 1: OCPQ Multi-Object Invariant Verification
      {:ok, action2} = ClosedLoop.trigger_cycle(:test_closed_loop)
      assert action2.type == :ocpq_invariant_audit
      assert action2.status == :satisfied
      assert is_binary(action2.receipt_hash)

      # Cycle 2: Autonomous Cluster Rebalance
      {:ok, action3} = ClosedLoop.trigger_cycle(:test_closed_loop)
      assert action3.type == :cluster_rebalance
      assert action3.status == :optimal
      assert is_binary(action3.receipt_hash)

      {:ok, status} = ClosedLoop.get_status(:test_closed_loop)
      assert status.cycle_count == 3
      assert status.remediation_count == 1
    end

    test "supports pausing and resuming autonomous mode" do
      assert :ok = ClosedLoop.set_mode(:paused, :test_closed_loop)
      {:ok, status} = ClosedLoop.get_status(:test_closed_loop)
      assert status.mode == :paused

      assert :ok = ClosedLoop.set_mode(:autonomous, :test_closed_loop)
      {:ok, status2} = ClosedLoop.get_status(:test_closed_loop)
      assert status2.mode == :autonomous
    end
  end
end
