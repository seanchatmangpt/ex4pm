defmodule Ex4pm.DomainTest do
  use ExUnit.Case, async: false

  test "canonical datasets and engine capabilities project into Ash ETS resources" do
    raw = %{
      "objects" => %{"o1" => %{"type" => "Order"}},
      "events" => %{
        "e1" => %{
          "activity" => "create",
          "timestamp" => "2026-01-01T00:00:00Z",
          "objects" => ["o1"]
        }
      }
    }

    assert {:ok, log} = Ex4pm.OCEL.normalize(raw)
    assert {:ok, dataset} = Ex4pm.Domain.Projector.dataset(log)
    assert dataset.subject_hash == log.subject.hash
    assert dataset.event_count == 1

    capability =
      Ex4pm.Engine.Registry.candidates(:discover)
      |> Enum.find(&(&1.id == :beam))

    assert capability.standing == :partial_alive
    assert capability.reason == :candidate_available_unexecuted
    assert capability.evidence.executed == false

    assert {:ok, projected} = Ex4pm.Domain.Projector.capability(capability)
    assert projected.engine == :beam
    assert projected.standing == :partial_alive
    assert projected.reason == :candidate_available_unexecuted
    assert projected.evidence.executed == false
  end

  test "projects full OCEL log with E2O and O2O relations into Ash domain" do
    raw = %{
      "objects" => %{
        "agent-1" => %{"id" => "agent-1", "type" => "Agent", "role" => "compiler"},
        "repo-1" => %{
          "id" => "repo-1",
          "type" => "Repository",
          "url" => "https://github.com/ex4pm"
        }
      },
      "object_relationships" => [
        %{"source_id" => "agent-1", "target_id" => "repo-1", "qualifier" => "assigned_to"}
      ],
      "events" => [
        %{
          "id" => "ev-1",
          "activity" => "compile",
          "timestamp" => "2026-08-21T18:00:00Z",
          "relationships" => [
            %{"objectId" => "agent-1", "qualifier" => "executor"},
            %{"objectId" => "repo-1", "qualifier" => "target"}
          ]
        }
      ]
    }

    assert {:ok, log} = Ex4pm.OCEL.normalize(raw)
    assert {:ok, :projected} = Ex4pm.Domain.Projector.project_log(log)

    # Test Agent, AgentRun, Refusal projections
    assert {:ok, agent} =
             Ex4pm.Domain.Projector.agent(%{agent_id: "agent-007", runtime: "beam-otp27"})

    assert agent.agent_id == "agent-007"
    assert agent.standing == :alive

    assert {:ok, run} =
             Ex4pm.Domain.Projector.agent_run(%{
               run_id: "run-007",
               agent_id: "agent-007",
               repository: "ex4pm"
             })

    assert run.run_id == "run-007"
    assert run.status == :running

    assert {:ok, variant} = Ex4pm.Domain.Projector.variant(["admit", "construct", "verify"], 42)
    assert variant.count == 42
    assert variant.path == ["admit", "construct", "verify"]

    refusal = Ex4pm.Refusal.new(:no_authority, "Authority denied")
    assert {:ok, projected_refusal} = Ex4pm.Domain.Projector.refusal(refusal)
    assert projected_refusal.code == :no_authority
  end

  test "creates and queries all 10 Cognition and AutoSystems Ash resources" do
    # 1. CognitionBreed
    assert {:ok, breed} =
             Ash.create(Ex4pmDomain.CognitionBreed, %{
               name: "bayesian_network",
               category: :probabilistic,
               formalism: "DAG directed graphical model with CPTs",
               complexity: "NP-hard exact, polynomial poly-trees"
             })

    assert breed.name == "bayesian_network"
    assert breed.category == :probabilistic

    # 2. CognitionSession
    assert {:ok, session} =
             Ash.create(Ex4pmDomain.CognitionSession, %{
               agent_id: "agent-cognition-1",
               run_id: "run-cog-1",
               working_memory: %{"context" => "flight_dispatch"},
               goals: ["satisfy_invariants"]
             })

    assert session.agent_id == "agent-cognition-1"
    assert session.status == :active

    # 3. BayesianNetwork
    assert {:ok, bn} =
             Ash.create(Ex4pmDomain.BayesianNetwork, %{
               name: "dispatch_risk_bn",
               nodes: ["Weather", "Traffic", "Delay"],
               cpts: %{"Weather" => %{"clear" => 0.8, "storm" => 0.2}}
             })

    assert bn.name == "dispatch_risk_bn"

    # 4. PrologKb
    assert {:ok, kb} =
             Ash.create(Ex4pmDomain.PrologKb, %{
               name: "compliance_kb",
               clause_count: 5
             })

    assert kb.name == "compliance_kb"

    # 5. Plan
    assert {:ok, plan} =
             Ash.create(Ex4pmDomain.Plan, %{
               goal: ["receipt_minted"],
               initial_state: ["unverified"],
               steps: ["admit", "construct", "brce", "do"]
             })

    assert length(plan.steps) == 4

    # 6. BlackboardHypothesis
    assert {:ok, hyp} =
             Ash.create(Ex4pmDomain.BlackboardHypothesis, %{
               level: "process",
               content: "Deadlock detected in branch B",
               confidence: 0.95,
               session_id: session.id
             })

    assert hyp.confidence == 0.95

    # 7. TemporalModel
    assert {:ok, tm} =
             Ash.create(Ex4pmDomain.TemporalModel, %{
               name: "sla_intervals",
               ltl_formulas: ["response(admit, receipt)"]
             })

    assert tm.name == "sla_intervals"

    # 8. ParetoFrontier
    assert {:ok, pf} =
             Ash.create(Ex4pmDomain.ParetoFrontier, %{
               name: "process_variant_tradeoffs",
               candidates_count: 10,
               frontier_size: 3
             })

    assert pf.frontier_size == 3

    # 9. InterviewSession
    assert {:ok, is} =
             Ash.create(Ex4pmDomain.InterviewSession, %{
               agent_id: "agent-candidate-42",
               ambiguity_score: 0.25
             })

    assert is.ambiguity_score == 0.25

    # 10. AdversarialAudit
    assert {:ok, audit} =
             Ash.create(Ex4pmDomain.AdversarialAudit, %{
               target_id: "batch-101",
               passed?: true,
               violations_count: 0
             })

    assert audit.passed? == true
  end
end
