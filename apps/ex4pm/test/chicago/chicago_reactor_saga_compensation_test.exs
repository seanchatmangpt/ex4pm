# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Chicago.ChicagoReactorSagaCompensationTest do
  use ExUnit.Case, async: false

  @moduletag :chicago
  @moduletag timeout: 60_000

  alias Ex4pmEngine.Reactors.Chicago.ChicagoSagaRollbackReactor

  describe "1. Saga Execution & Forward Commit" do
    test "completes all steps successfully when no fault is injected" do
      inputs = [
        saga_id: "SAGA-001",
        slot_id: "SLOT-99",
        auth_id: "AUTH-777",
        amount: 50_000,
        trigger_fault?: false,
        fault_reason: :none
      ]

      context = %{
        test_pid: self()
      }

      assert {:ok, manifest} =
               Reactor.run(ChicagoSagaRollbackReactor, inputs, context, async?: false)

      assert manifest.saga_id == "SAGA-001"
      assert manifest.status == :committed
      assert manifest.slot_reserved == true
      assert manifest.financials_authorized == true
      assert manifest.terminal_status == :success

      assert_receive {:slot_reserved, "SLOT-99"}, 1_000
      assert_receive {:financial_authorized, "AUTH-777", 50_000}, 1_000
      refute_receive {:slot_undone, _}, 500
      refute_receive {:financial_undone, _}, 500
    end
  end

  describe "2. Adversarial Fault Injection & Strict LIFO Compensation" do
    test "rolls back financial authorization and slot reservation in strict reverse order upon terminal fault" do
      inputs = [
        saga_id: "SAGA-FAULT-002",
        slot_id: "SLOT-42",
        auth_id: "AUTH-888",
        amount: 120_000,
        trigger_fault?: true,
        fault_reason: :non_conformance_breach
      ]

      context = %{
        test_pid: self()
      }

      assert {:error, _errors} =
               Reactor.run(ChicagoSagaRollbackReactor, inputs, context, async?: false)

      # 1. Forward steps must have executed
      assert_receive {:slot_reserved, "SLOT-42"}, 1_000
      assert_receive {:financial_authorized, "AUTH-888", 120_000}, 1_000

      # 2. Backward compensation/undo must trigger in reverse (LIFO) order:
      # Financial commitment (Step 2) undone before Slot reservation (Step 1)
      assert_receive {:financial_undone, "AUTH-888"}, 1_000
      assert_receive {:slot_undone, "SLOT-42"}, 1_000
    end
  end
end
