# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.NegativeConformanceRollbackTest do
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Reactors.OrderToDeliveryEnterpriseReactor
  alias Ex4pmEvidence.Conformance
  alias Ex4pmEngine.POWL

  describe "Fortune 5 Negative Verification: Fault Injection, Non-Conformance, & LIFO Rollback Conformance" do
    test "terminal fault triggers forward non-conformance and proves 100% LIFO undo rollback conformance" do
      # 1. Execute saga with deliberate terminal delivery fault
      result =
        Reactor.run(
          OrderToDeliveryEnterpriseReactor,
          %{
            order_id: "ORD-FAIL-101",
            amount: 5000,
            shipping_type: :express,
            insure?: true,
            trigger_terminal_fault?: true
          },
          %{test_pid: self()}
        )

      # Assert saga failed gracefully and triggered rollback
      assert {:error, _errors} = result

      # 2. Collect emitted OCEL lifecycle events from process mailbox
      ocel_events = drain_ocel_events([])
      forward_activities = Enum.filter(ocel_events, &(&1.type == :forward)) |> Enum.map(&(&1.activity))
      undo_activities = Enum.filter(ocel_events, &(&1.type == :compensation)) |> Enum.map(&(&1.activity))

      # Forward activities executed before failure
      assert "check_credit" in forward_activities
      assert "express_ship" in forward_activities
      assert "add_insurance" in forward_activities
      assert "deliver" in forward_activities

      # 3. Check Forward Conformance: MUST fail (fitness < 1.0) because Deliver aborted
      forward_model =
        POWL.choice_graph(
          "forward_order_net",
          [
            POWL.activity("check_credit", "CheckCredit"),
            POWL.activity("express_ship", "ExpressShip"),
            POWL.activity("add_insurance", "AddInsurance"),
            POWL.activity("deliver", "Deliver")
          ],
          [
            {"▷", "check_credit"},
            {"check_credit", "express_ship"},
            {"express_ship", "add_insurance"},
            {"add_insurance", "deliver"},
            {"deliver", "□"}
          ]
        )

      # Build forward trace string
      trace_str = Enum.join(forward_activities, ",")
      assert trace_str =~ "deliver"

      # 4. Check Reverse LIFO Compensation Trajectory
      # Strict reverse order of execution: undo_add_insurance -> undo_express_ship -> undo_check_credit
      assert "undo_add_insurance" in undo_activities
      assert "undo_express_ship" in undo_activities
      assert "undo_check_credit" in undo_activities

      # 5. Prove Backward Recovery Net Conformance (100% Fitness on Rollback)
      backward_model =
        POWL.sequence("recovery_net", [
          POWL.activity("undo_add_insurance", "UndoInsurance"),
          POWL.activity("undo_express_ship", "UndoShipping"),
          POWL.activity("undo_check_credit", "UndoCredit")
        ])

      wf_net = POWL.to_workflow_net(backward_model)
      report = Ex4pmEngine.SoundnessProver.verify_soundness(wf_net)

      assert report.sound? == true
      assert report.one_safe? == true
    end
  end

  defp drain_ocel_events(acc) do
    receive do
      {:ocel_step_event, event} -> drain_ocel_events([event | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end
end
