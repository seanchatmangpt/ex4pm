defmodule Ex4pmEngine.Adversarial.Global8020NegativeTest do
  @moduledoc """
  Exhaustive Negative Test Suite covering the global 80/20 of enterprise process failure modes:
  1. Rogue execution / skipped compliance approvals (A* Alignment penalty).
  2. Data guard privilege escalation (DAPN first-order rejection).
  3. Lingering resource / token leakage (Soundness Prover proper completion failure).
  4. Multi-agent circular wait deadlock (Choreography prover deadlock detection).
  5. Multi-agent orphan message buffer leak (Choreography prover channel invariance failure).
  6. Temporal order violation & mutual exclusion breach (LTLf model checking failure).
  7. State machine illegal transition skip (Ash changeset guard rejection).
  """

  use ExUnit.Case, async: true

  alias Ex4pmEngine.{Alignment, Choreography, DAPN, LTLf, SoundnessProver}
  alias Ex4pmEngine.Choreography.{AgentNet, Channel}

  describe "1. Rogue Execution & Compliance Step Omission (A* Alignment)" do
    test "adversarial trace omitting mandatory SecurityReview is detected and penalized" do
      compliant_net = %{
        transitions: %{
          submit: %{inputs: ["p_in"], outputs: ["p_1"], label: "Submit"},
          sec_review: %{inputs: ["p_1"], outputs: ["p_2"], label: "SecurityReview"},
          deploy: %{inputs: ["p_2"], outputs: ["p_out"], label: "Deploy"}
        },
        initial_marking: ["p_in"],
        final_marking: ["p_out"]
      }

      # Rogue trace skips SecurityReview directly to Deploy
      rogue_trace = ["Submit", "Deploy"]

      assert {:ok, result} = Alignment.align_trace(rogue_trace, compliant_net)
      assert result.fitness < 1.0
      assert result.model_moves_count >= 1

      # Verify the missing model move exists in moves
      missing_model_moves = Enum.filter(result.moves, &(&1.type == :model_only))
      assert missing_model_moves != []
    end
  end

  describe "2. Data Guard Privilege Escalation (DAPN)" do
    test "unauthorized transaction exceeding spend limit is strictly rejected by first-order guard" do
      dapn = %{
        transitions: %{
          req: %{
            inputs: ["p_in"],
            outputs: ["p_req"],
            label: "RequestTransfer",
            guard: :always_true
          },
          exec: %{
            inputs: ["p_req"],
            outputs: ["p_out"],
            label: "ExecuteTransfer",
            guard:
              {:and,
               [
                 {:attr, :role, :eq, "senior_treasurer"},
                 {:attr, :amount, :lte, 100_000}
               ]}
          }
        },
        initial_marking: ["p_in"],
        final_marking: ["p_out"]
      }

      # Rogue attacker with junior_role attempting 250,000 transfer
      hostile_trace = [
        %{
          activity: "RequestTransfer",
          attributes: %{"amount" => 250_000, "role" => "junior_analyst"}
        },
        %{
          activity: "ExecuteTransfer",
          attributes: %{"amount" => 250_000, "role" => "junior_analyst"}
        }
      ]

      assert {:error, {:guard_or_control_violation, "ExecuteTransfer", _marking, _attrs}} =
               DAPN.execute_dapn_trace(hostile_trace, dapn)
    end
  end

  describe "3. Lingering Resource & Token Leakage (Soundness Prover)" do
    test "unsound model that spawns duplicate tokens without consuming them fails proper completion" do
      # Leaky net: t_fork spawns token into p_leak which is never cleaned up
      leaky_net = %{
        places: ["p_in", "p_main", "p_leak", "p_out"],
        transitions: %{
          t_fork: %{inputs: ["p_in"], outputs: ["p_main", "p_leak"], label: "fork"},
          t_finish: %{inputs: ["p_main"], outputs: ["p_out"], label: "finish"}
        },
        initial_marking: ["p_in"],
        final_marking: ["p_out"]
      }

      report = SoundnessProver.verify_soundness(leaky_net)

      assert report.sound? == false
      assert report.proper_completion? == false
      assert report.counterexamples != []
    end
  end

  describe "4. Multi-Agent Circular Wait Deadlock (Choreography)" do
    test "communicating choreography with reciprocal wait deadlock is proved unsound" do
      # Both agents wait for messages from each other before proceeding
      agent1_net = %{
        places: ["p_in", "p_out"],
        transitions: %{
          recv_first: %{inputs: ["p_in"], outputs: ["p_out"], label: "WaitA"}
        },
        initial_marking: ["p_in"],
        final_marking: ["p_out"]
      }

      agent1 = %AgentNet{
        id: "agent_a",
        net: agent1_net,
        sends: %{},
        receives: %{recv_first: "chan_ba"}
      }

      agent2_net = %{
        places: ["p_in", "p_out"],
        transitions: %{
          recv_first: %{inputs: ["p_in"], outputs: ["p_out"], label: "WaitB"}
        },
        initial_marking: ["p_in"],
        final_marking: ["p_out"]
      }

      agent2 = %AgentNet{
        id: "agent_b",
        net: agent2_net,
        sends: %{},
        receives: %{recv_first: "chan_ab"}
      }

      channels = [
        %Channel{name: "chan_ab", source_agent: "agent_a", target_agent: "agent_b"},
        %Channel{name: "chan_ba", source_agent: "agent_b", target_agent: "agent_a"}
      ]

      report = Choreography.verify_choreography([agent1, agent2], channels)
      assert report.sound? == false
      assert report.deadlocks != []
    end
  end

  describe "5. Multi-Agent Orphan Message Buffer Leak (Choreography)" do
    test "choreography where sender emits message that receiver never consumes leaves orphan buffer" do
      # Agent A sends message
      agent1_net = %{
        places: ["p_in", "p_out"],
        transitions: %{
          send_extra: %{inputs: ["p_in"], outputs: ["p_out"], label: "SendNotice"}
        },
        initial_marking: ["p_in"],
        final_marking: ["p_out"]
      }

      agent1 = %AgentNet{
        id: "sender",
        net: agent1_net,
        sends: %{send_extra: "orphan_channel"},
        receives: %{}
      }

      # Agent B terminates without consuming orphan_channel
      agent2_net = %{
        places: ["p_in", "p_out"],
        transitions: %{
          finish: %{inputs: ["p_in"], outputs: ["p_out"], label: "DoWork"}
        },
        initial_marking: ["p_in"],
        final_marking: ["p_out"]
      }

      agent2 = %AgentNet{
        id: "receiver",
        net: agent2_net,
        sends: %{},
        receives: %{}
      }

      channels = [
        %Channel{name: "orphan_channel", source_agent: "sender", target_agent: "receiver"}
      ]

      report = Choreography.verify_choreography([agent1, agent2], channels)
      assert report.orphan_messages? == true
      assert report.sound? == false
    end
  end

  describe "6. Temporal Logic ($LTL_f$) Violations" do
    test "trace violating response constraint (A without eventual B) evaluates to false" do
      constraint = LTLf.response("PaymentInitiated", "ReceiptIssued")
      invalid_trace = ["PaymentInitiated", "AuditLogged"]

      assert LTLf.evaluate(invalid_trace, constraint) == false
    end

    test "trace violating precedence constraint (B occurring before A) evaluates to false" do
      constraint = LTLf.precedence("SecurityCheck", "DeployProduction")
      invalid_trace = ["DeployProduction", "SecurityCheck"]

      assert LTLf.evaluate(invalid_trace, constraint) == false
    end

    test "trace violating non-coexistence (mutually exclusive A and B both occurring) evaluates to false" do
      constraint = LTLf.non_coexistence("ApproveLoan", "RejectLoan")
      invalid_trace = ["SubmitApplication", "ApproveLoan", "RejectLoan"]

      assert LTLf.evaluate(invalid_trace, constraint) == false
    end
  end

  describe "7. Illegal State Machine Transition Skips (Pure State Machine Net)" do
    test "attempting to skip intermediate states directly to closed is rejected" do
      net = %{
        transitions: %{
          triage: %{inputs: ["p_reported"], outputs: ["p_triaged"], label: "Triage"},
          investigate: %{inputs: ["p_triaged"], outputs: ["p_in_prog"], label: "Investigate"},
          resolve: %{inputs: ["p_in_prog"], outputs: ["p_resolved"], label: "Resolve"},
          close: %{inputs: ["p_resolved"], outputs: ["p_closed"], label: "Close"}
        },
        initial_marking: ["p_reported"],
        final_marking: ["p_closed"]
      }

      illegal_trace = ["Triage", "Close"]
      result = Alignment.align(illegal_trace, net)

      assert result.cost > 0
      assert result.exact_match? == false
    end

    test "ChangeOrder cannot execute without prior approval in sound workflow net" do
      net = %{
        transitions: %{
          review: %{inputs: ["p_draft"], outputs: ["p_reviewed"], label: "Review"},
          approve: %{inputs: ["p_reviewed"], outputs: ["p_approved"], label: "Approve"},
          execute: %{inputs: ["p_approved"], outputs: ["p_executed"], label: "Execute"}
        },
        initial_marking: ["p_draft"],
        final_marking: ["p_executed"]
      }

      unapproved_trace = ["Review", "Execute"]
      result = Alignment.align(unapproved_trace, net)

      assert result.cost > 0
      assert result.exact_match? == false
    end
  end
end
