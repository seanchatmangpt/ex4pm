defmodule Ex4pmEngine.Adversarial.ReactorSagaTest do
  use ExUnit.Case, async: false

  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.WorkflowNet

  describe "Reactor Saga LIFO Compensation & Rollback Mechanics" do
    test "models 4-step transactional saga with failure rollback as sound 1-safe workflow net" do
      # Model a 4-step forward pipeline with backward compensation arcs:
      # Forward: step1 -> step2 -> step3 -> step4
      # On failure at step 3: compensate3 -> undo2 -> undo1 -> terminal_fail
      act1 = POWL.activity("act1", "ProvisionResource")
      act2 = POWL.activity("act2", "DebitAccount")
      act3 = POWL.activity("act3", "NotifyThirdParty")
      undo2 = POWL.activity("undo2", "RefundAccount")
      undo1 = POWL.activity("undo1", "DeprovisionResource")

      # Successful branch: act1 -> act2 -> act3
      success_po =
        POWL.partial_order("success_path", [act1, act2, act3], [
          {"act1", "act2"},
          {"act2", "act3"}
        ])

      # Failure compensation branch: act1 -> act2 -> undo2 -> undo1
      failure_po =
        POWL.partial_order("failure_path", [act1, act2, undo2, undo1], [
          {"act1", "act2"},
          {"act2", "undo2"},
          {"undo2", "undo1"}
        ])

      saga_choice = POWL.choice("saga_root", [success_po, failure_po])

      nodes = %{
        "act1" => act1,
        "act2" => act2,
        "act3" => act3,
        "undo2" => undo2,
        "undo1" => undo1,
        "success_path" => success_po,
        "failure_path" => failure_po,
        "saga_root" => saga_choice
      }

      assert {:ok, model} = POWL.new(nodes, root: "saga_root")
      assert {:ok, wf_net} = POWL.to_workflow_net(model)

      assert :ok = WorkflowNet.validate_structure(wf_net)
      assert {:ok, report} = WorkflowNet.verify_soundness(wf_net)

      assert report.sound? == true
      assert report.one_safe? == true
      assert report.option_to_complete? == true
      assert report.proper_completion? == true
    end
  end
end
