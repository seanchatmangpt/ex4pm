defmodule Ex4pmCore.BlueprintsTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.Blueprints.{IncidentManagement, GovernanceApproval, LedgerTransfer}

  describe "Enterprise Process Blueprints" do
    test "instantiates IncidentManagement blueprint" do
      bp = IncidentManagement.blueprint()
      assert %ProcessIR{} = bp
      assert Map.has_key?(bp.activities, "detect_incident")
      assert Map.has_key?(bp.activities, "close_incident")
      assert Map.has_key?(bp.policies, "p99_remediation_sla")
    end

    test "instantiates GovernanceApproval blueprint" do
      bp = GovernanceApproval.blueprint()
      assert %ProcessIR{} = bp
      assert Map.has_key?(bp.activities, "submit_change")
      assert Map.has_key?(bp.activities, "first_review")
      assert Map.has_key?(bp.activities, "second_review")
      assert Map.has_key?(bp.policies, "sod_two_person_rule")
    end

    test "instantiates LedgerTransfer blueprint" do
      bp = LedgerTransfer.blueprint()
      assert %ProcessIR{} = bp
      assert Map.has_key?(bp.activities, "validate_accounts")
      assert Map.has_key?(bp.activities, "debit_source_account")
      assert Map.has_key?(bp.activities, "reconcile_transfer_balance")
    end
  end
end
