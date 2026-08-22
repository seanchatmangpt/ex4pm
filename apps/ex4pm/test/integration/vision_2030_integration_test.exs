defmodule Ex4pm.Integration.Vision2030IntegrationTest do
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Hypergraph
  alias Ex4pmEngine.GenerativeAutonomic
  alias Ex4pmEvidence.CapabilityMesh

  # Sample Ash Resource for Hypergraph Synthesis
  defmodule VisionPaymentResource do
    use Ash.Resource,
      domain: Ex4pm.Integration.Vision2030IntegrationTest.VisionDomain,
      data_layer: Ash.DataLayer.Ets

    actions do
      defaults([:read])

      create :authorize do
        primary?(true)
        accept([:amount, :currency])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:amount, :decimal, allow_nil?: false)
      attribute(:currency, :string, default: "USD")
    end
  end

  defmodule VisionDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(VisionPaymentResource)
    end
  end

  describe "Vision 2030 Autonomic Semantic Process Integration" do
    test "proves the full Vision 2030 loop: Hypergraph -> Soundness Anomaly -> Generative Repair -> Hot-Code Reload -> Merkle Capability Mesh" do
      # 1. Unified Hypergraph Synthesis (Ash + R2RML + OCPN)
      hypergraph = Hypergraph.from_resource(VisionPaymentResource)
      assert hypergraph.table_name == "visionpaymentresource"
      assert String.contains?(hypergraph.r2rml_turtle, "rr:TriplesMap")
      assert hypergraph.ocpn.object_types == ["VisionPaymentResource"]

      # 2. Generative Autonomic Self-Healing of Unsound Reactor Saga
      target_module = VisionAutoRepairedReactor

      assert {:ok, repair_result} =
               GenerativeAutonomic.repair_and_hot_reload(
                 target_module,
                 :faulty_payment_step,
                 :compensate_payment_step,
                 "Payment"
               )

      assert repair_result.status == :hot_code_reloaded
      assert repair_result.soundness_proof.sound? == true

      # 3. Execute the newly compiled, hot-code reloaded Reactor in-memory
      assert {:ok, saga_output} =
               Reactor.run(target_module, %{input_data: %{order_id: "ord_100", amount: 250}})

      assert saga_output.faulty_payment_step == :bypassed
      assert saga_output.compensate_payment_step == :compensated

      # 4. Record Cryptographic Capability in Merkle Mesh
      assert {:ok, mesh_node} =
               CapabilityMesh.record_capability(
                 "agent_vision_2030",
                 "autonomic_self_healing_saga",
                 :passed,
                 info: "Autonomous 1-safe soundness repair and hot-code reload verified."
               )

      assert is_binary(mesh_node.merkle_root)
      assert mesh_node.receipt.standing == :ALIVE
      assert String.contains?(mesh_node.earl.turtle, "earl:Assertion")
    end
  end
end
