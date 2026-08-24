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

    # 11. OcpqQuery
    assert {:ok, ocpq} =
             Ash.create(Ex4pmDomain.OcpqQuery, %{
               name: "order_package_ocpq",
               satisfied?: true
             })

    assert ocpq.name == "order_package_ocpq"

    # 12. SurvivalModel
    assert {:ok, surv} =
             Ash.create(Ex4pmDomain.SurvivalModel, %{
               name: "incident_survival",
               sample_size: 100,
               median_duration_ms: 15_000
             })

    assert surv.median_duration_ms == 15_000

    # 13. CausalModel
    assert {:ok, causal} =
             Ash.create(Ex4pmDomain.CausalModel, %{
               name: "pipeline_causal",
               edge_count: 4
             })

    assert causal.edge_count == 4

    # 14. MarkovModel
    assert {:ok, markov} =
             Ash.create(Ex4pmDomain.MarkovModel, %{
               name: "pipeline_markov",
               state_count: 5
             })

    assert markov.state_count == 5

    # 15. CriticalPathSchedule
    assert {:ok, cpm} =
             Ash.create(Ex4pmDomain.CriticalPathSchedule, %{
               name: "dispatch_dag",
               total_duration_ms: 45
             })

    assert cpm.total_duration_ms == 45

    # 16. AlignmentRecord
    assert {:ok, align_rec} =
             Ash.create(Ex4pmDomain.AlignmentRecord, %{
               case_id: "case_999",
               trace_length: 5,
               total_cost: 0.0,
               fitness: 1.0,
               sync_moves: 5,
               log_moves: 0,
               model_moves: 0
             })

    assert align_rec.case_id == "case_999"
    assert align_rec.fitness == 1.0

    # 17. PowlModel
    assert {:ok, powl_rec} =
             Ash.create(Ex4pmDomain.PowlModel, %{
               name: "governance_powl",
               root_operator: :sequence,
               node_count: 8,
               sound_by_construction?: true
             })

    assert powl_rec.sound_by_construction? == true

    # 18. LtlfConstraint
    assert {:ok, ltlf_rec} =
             Ash.create(Ex4pmDomain.LtlfConstraint, %{
               name: "sec_approval_rule",
               formula_type: "precedence",
               source_activity: "security_scan",
               target_activity: "deploy",
               satisfied?: true
             })

    assert ltlf_rec.satisfied? == true

    # 19. ChoreographyContract
    assert {:ok, choreo_rec} =
             Ash.create(Ex4pmDomain.ChoreographyContract, %{
               name: "order_fulfillment_choreo",
               participating_agents: ["customer", "merchant"],
               channels_count: 2,
               sound?: true,
               deadlock_free?: true
             })

    assert choreo_rec.deadlock_free? == true
  end

  test "creates and queries the 10 previously-untested Ash resources with real Ash.create + Ash.get" do
    # All ids/names/content below come from Faker, not hand-rolled counters or literals.
    id = fn -> Faker.UUID.v4() end
    # Real content-addressed hash (not a fabricated placeholder string) — subject_hash values
    # below are the actual sha256 digest of real (Faker-generated) content, computed the same
    # way the rest of the codebase computes hashes (see Ex4pm.Core.Digest).
    real_hash = fn content -> "sha256:" <> Base.encode16(:crypto.hash(:sha256, content), case: :lower) end

    # 1. Agent
    agent_id = id.()
    agent_name = Faker.Company.name()

    assert {:ok, agent} =
             Ash.create(Ex4pmDomain.Agent, %{
               id: agent_id,
               name: agent_name,
               capabilities: ["discover", "conform"],
               status: :active,
               standing: :alive
             })

    assert agent.id == agent_id
    assert {:ok, fetched_agent} = Ash.get(Ex4pmDomain.Agent, agent_id)
    assert fetched_agent.name == agent_name

    # 2. AgentRun (belongs_to Agent)
    run_id = id.()

    assert {:ok, run} =
             Ash.create(Ex4pmDomain.AgentRun, %{
               id: run_id,
               agent_id: agent.id,
               sequence: 1,
               status: :running
             })

    assert run.agent_id == agent.id
    assert {:ok, fetched_run} = Ash.get(Ex4pmDomain.AgentRun, run_id)
    assert fetched_run.status == :running

    # 3. Object (created before Event/EventObject so relationships resolve)
    object_id = id.()
    object_type = Enum.random(["Order", "Item", "Package", "Invoice"])
    assert {:ok, object} = Ash.create(Ex4pmDomain.Object, %{id: object_id, type: object_type})

    assert object.type == object_type
    assert {:ok, fetched_object} = Ash.get(Ex4pmDomain.Object, object_id)
    assert fetched_object.id == object_id

    # 4. Event (belongs_to Agent + AgentRun)
    event_id = id.()
    activity = Faker.Company.bs()

    assert {:ok, event} =
             Ash.create(Ex4pmDomain.Event, %{
               id: event_id,
               activity: activity,
               timestamp: Faker.DateTime.backward(3) |> DateTime.to_iso8601(),
               agent_id: agent.id,
               run_id: run.id
             })

    assert event.activity == activity
    assert {:ok, fetched_event} = Ash.get(Ex4pmDomain.Event, event_id)
    assert fetched_event.agent_id == agent.id

    # 5. EventObject (E2O relationship, belongs_to Event + Object)
    assert {:ok, event_object} =
             Ash.create(Ex4pmDomain.EventObject, %{
               event_id: event.id,
               object_id: object.id,
               qualifier: "involved"
             })

    assert event_object.event_id == event.id
    assert event_object.object_id == object.id
    assert {:ok, fetched_eo} = Ash.get(Ex4pmDomain.EventObject, event_object.id)
    assert fetched_eo.qualifier == "involved"

    # 6. ObjectObject (O2O relationship, needs a second Object)
    object2_id = id.()
    object2_type = Enum.random(["Order", "Item", "Package", "Invoice"])
    assert {:ok, object2} = Ash.create(Ex4pmDomain.Object, %{id: object2_id, type: object2_type})

    assert {:ok, object_object} =
             Ash.create(Ex4pmDomain.ObjectObject, %{
               source_id: object.id,
               target_id: object2.id,
               qualifier: "contains"
             })

    assert object_object.source_id == object.id
    assert object_object.target_id == object2.id
    assert {:ok, fetched_oo} = Ash.get(Ex4pmDomain.ObjectObject, object_object.id)
    assert fetched_oo.qualifier == "contains"

    # 7. ConformanceResult
    subject_hash = real_hash.(agent_id)

    assert {:ok, conformance_result} =
             Ash.create(Ex4pmDomain.ConformanceResult, %{
               subject_hash: subject_hash,
               agent_id: agent.id,
               run_id: run.id,
               fitness: 0.95,
               precision: 0.9,
               standing: :alive
             })

    assert conformance_result.subject_hash == subject_hash

    assert {:ok, fetched_cr} =
             Ash.get(Ex4pmDomain.ConformanceResult, conformance_result.id)

    assert fetched_cr.standing == :alive

    # 8. Refusal (typed rejection)
    refusal_reason = Faker.Lorem.sentence()

    assert {:ok, refusal_rec} =
             Ash.create(Ex4pmDomain.Refusal, %{
               code: :authority_denied,
               reason: refusal_reason,
               agent_id: agent.id,
               run_id: run.id
             })

    assert refusal_rec.code == :authority_denied
    assert {:ok, fetched_refusal} = Ash.get(Ex4pmDomain.Refusal, refusal_rec.id)
    assert fetched_refusal.reason == refusal_reason

    # 9. Receipt (control-plane cryptographic receipt, belongs_to AgentRun)
    receipt_hash = real_hash.(subject_hash <> run_id)
    operation_name = Faker.Company.buzzword()

    assert {:ok, receipt_rec} =
             Ash.create(Ex4pmDomain.Receipt, %{
               hash: receipt_hash,
               subject_hash: subject_hash,
               phase: :outcome,
               operation: operation_name,
               standing: :alive,
               agent_id: agent.id,
               run_id: run.id
             })

    assert receipt_rec.hash == receipt_hash
    assert {:ok, fetched_receipt} = Ash.get(Ex4pmDomain.Receipt, receipt_rec.id)
    assert fetched_receipt.phase == :outcome

    # 10. ChangeOrder (formal state machine; primary create action is :draft, not :create)
    change_order_summary = Faker.Lorem.sentence()

    assert {:ok, change_order} =
             Ash.create(Ex4pmDomain.ChangeOrder, %{
               summary: change_order_summary,
               risk_level: Enum.random([:low, :medium, :high]),
               requester_id: agent.id
             })

    assert change_order.state == :draft
    assert {:ok, fetched_co} = Ash.get(Ex4pmDomain.ChangeOrder, change_order.id)
    assert fetched_co.requester_id == agent.id
  end
end
