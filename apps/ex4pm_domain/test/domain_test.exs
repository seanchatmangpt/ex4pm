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
end
