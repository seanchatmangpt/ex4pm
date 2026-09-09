defmodule Ex4pmEvidence.Adversarial.PolicyVisibilityTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.{Activity, Policy}
  alias Ex4pmEvidence.Conformance

  describe "Actor & Field-Level Policy Enforcement" do
    test "detects separation-of-duties (SoD) policy violation when actor performs conflicting actions" do
      # SoD Policy: Same actor cannot both approve and pay an invoice
      policy = %Policy{
        id: "sod_approval_payment",
        type: :sod,
        target_activities: ["approve_invoice", "pay_invoice"],
        description: "An actor who approves an invoice cannot pay it."
      }

      ir = %ProcessIR{
        id: "invoice_proc",
        activities: %{
          "approve_invoice" => %Activity{id: "approve_invoice", label: "Approve"},
          "pay_invoice" => %Activity{id: "pay_invoice", label: "Pay"}
        },
        policies: %{policy.id => policy}
      }

      # Test log with policy violation (same actor "user_123" for both)
      log = %{
        "objects" => %{"inv_1" => %{"type" => "Invoice"}},
        "events" => %{
          "e1" => %{
            "activity" => "approve_invoice",
            "timestamp" => "2026-01-01T10:00:00Z",
            "objects" => ["inv_1"],
            "attributes" => %{"actor" => "user_123"}
          },
          "e2" => %{
            "activity" => "pay_invoice",
            "timestamp" => "2026-01-01T11:00:00Z",
            "objects" => ["inv_1"],
            "attributes" => %{"actor" => "user_123"}
          }
        }
      }

      assert {:ok, vec} = Conformance.evaluate(log, ir, object_type: "Invoice")
      assert vec.policy_conformance < 1.0
      assert Enum.any?(vec.violations, fn v -> v.dimension == :policy end)
    end
  end
end
