defmodule Ex4pm.Integration.Vision2040IntegrationTest do
  use ExUnit.Case, async: false

  alias Ex4pmEngine.QuantumProcess
  alias Ex4pmEngine.ZkOcpn
  alias Ex4pmEngine.Topos
  alias Ex4pmEngine.OcelToLatex
  alias Ex4pmEngine.OCPN
  alias Ex4pmEngine.OCPN.SoundnessEngine

  describe "Vision 2040 Autonomic Semantic Process Substrate" do
    test "verifies Quantum Superpositional Marking Evolution & Measurement Collapse" do
      places = ["p_init", "p_branch_a", "p_branch_b", "p_sink"]
      qstate = QuantumProcess.new(places)

      # 1. State vector has initial amplitude 1.0 at p_init
      assert qstate.amplitudes["p_init"] == 1.0
      assert qstate.amplitudes["p_sink"] == 0.0

      # 2. Evolve state into superposition across branch_a and branch_b
      evolved = QuantumProcess.evolve_superposition(qstate, ["p_branch_a", "p_branch_b"])
      assert_in_delta evolved.amplitudes["p_branch_a"], 0.7071, 0.001
      assert_in_delta evolved.amplitudes["p_branch_b"], 0.7071, 0.001

      # 3. Collapse state to sound terminal sink
      assert {:ok, measurement} = QuantumProcess.measure_collapse(evolved, "p_sink")
      assert measurement.collapsed_marking == ["p_sink"]
      assert measurement.sound_terminal? == true
    end

    test "verifies Zero-Knowledge Non-Interactive OCPN (zk-OCPN) R1CS Proof Generation" do
      net =
        OCPN.new("cross_enterprise_settlement", ["Ledger", "Trade"])
        |> OCPN.add_place("p_init", "Ledger", initial: true)
        |> OCPN.add_place("p_settled", "Ledger", terminal: true)
        |> OCPN.add_transition("t_settle", "Atomic Settlement", ["Ledger", "Trade"])
        |> OCPN.add_arc("p_init", "t_settle", "Ledger")
        |> OCPN.add_arc("t_settle", "p_settled", "Ledger")

      execution_trace = ["t_init", "t_settle"]

      # 1. Synthesize R1CS Zero-Knowledge Circuit
      zk_circuit = ZkOcpn.synthesize_circuit(net, execution_trace)
      assert zk_circuit.constraints_count > 0
      assert is_binary(zk_circuit.r1cs_digest)

      # 2. Verify zk-Proof in O(1) time
      public_claims = %{"initial_marking_hash" => "hash_m0_cross_enterprise_settlement"}
      assert {:ok, proof_result} = ZkOcpn.verify_proof(zk_circuit, public_claims)
      assert proof_result.verified? == true
      assert proof_result.zero_knowledge_soundness == :proven
    end

    test "verifies Topos Sheaf Morphogenesis preserving 1-Safe Soundness" do
      # Sheaf with 3 category objects and 2 morphisms
      sheaf =
        Topos.from_requirements(
          "autonomous_energy_grid",
          ["grid_source", "transformer", "consumer_sink"],
          [{"grid_source", "transformer"}, {"transformer", "consumer_sink"}]
        )

      # Materialize 1-Safe Sound OCPN through categorical functor
      assert {:ok, sound_ocpn} = Topos.materialize_sound_ocpn(sheaf)
      assert {:ok, result} = SoundnessEngine.verify_reachability(sound_ocpn, "ToposObject")
      assert result.sound? == true
      assert result.terminal_reachable? == true
    end

    test "exports IEEE OCEL 2.0 Production Benchmark to LaTeX Tables" do
      ocel_path = "/Users/sac/xaas/priv/ocel/ash-actions.ndjson"
      output_path = "docs/thesis/chapters/generated_ocel_benchmark_tables.tex"

      assert {:ok, latex_snippet} = OcelToLatex.export_latex(ocel_path, output: output_path)
      assert String.contains?(latex_snippet, "\\begin{table}")
      assert String.contains?(latex_snippet, "Shannon Log Entropy")
      assert String.contains?(latex_snippet, "capability\\_liveness")
      assert File.exists?(output_path)
    end
  end
end
