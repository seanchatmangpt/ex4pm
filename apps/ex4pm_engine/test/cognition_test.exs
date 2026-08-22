defmodule Ex4pm.Engine.CognitionTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Engine

  alias Ex4pmEngine.Cognition.{
    BayesianNetwork,
    Interview,
    Planner,
    Planner.Action,
    Prolog
  }

  test "Bayesian Network computes exact posterior distribution with evidence" do
    nodes = ["Rain", "Sprinkler", "GrassWet"]

    cpts = %{
      "Rain" => %{"true" => 0.2, "false" => 0.8},
      "Sprinkler" => %{
        %{"Rain" => "true"} => %{"true" => 0.01, "false" => 0.99},
        %{"Rain" => "false"} => %{"true" => 0.4, "false" => 0.6}
      },
      "GrassWet" => %{
        %{"Rain" => "true", "Sprinkler" => "true"} => %{"true" => 0.99, "false" => 0.01},
        %{"Rain" => "true", "Sprinkler" => "false"} => %{"true" => 0.8, "false" => 0.2},
        %{"Rain" => "false", "Sprinkler" => "true"} => %{"true" => 0.9, "false" => 0.1},
        %{"Rain" => "false", "Sprinkler" => "false"} => %{"true" => 0.0, "false" => 1.0}
      }
    }

    bn = BayesianNetwork.new(nodes, cpts)

    # P(Rain | GrassWet = true)
    assert {:ok, result} =
             Engine.execute(:cognition, {:bayesian_infer, bn},
               query: "Rain",
               evidence: %{"GrassWet" => "true"}
             )

    assert result.standing == :alive
    assert result.value.distribution["true"] > 0.3
    assert result.value.distribution["false"] > 0.5
  end

  test "Prolog Horn-clause engine unifies terms and resolves queries" do
    kb =
      Prolog.new()
      |> Prolog.assert_fact({:parent, :pam, :bob})
      |> Prolog.assert_fact({:parent, :tom, :bob})
      |> Prolog.assert_fact({:parent, :bob, :ann})
      |> Prolog.assert_rule({:grandparent, :X, :Z}, [{:parent, :X, :Y}, {:parent, :Y, :Z}])

    assert {:ok, result} =
             Engine.execute(:cognition, {:prolog_query, kb}, query: [{:grandparent, :pam, :ann}])

    assert result.standing == :alive
    assert result.value.solution_count == 1
  end

  test "STRIPS planner generates valid sequence of actions to reach goal" do
    actions = [
      %Action{
        name: "admit_agent",
        preconditions: ["agent_registered"],
        add_list: ["agent_admitted"],
        delete_list: []
      },
      %Action{
        name: "construct_workflow",
        preconditions: ["agent_admitted"],
        add_list: ["workflow_constructed"],
        delete_list: []
      },
      %Action{
        name: "execute_brce",
        preconditions: ["workflow_constructed"],
        add_list: ["receipt_minted"],
        delete_list: []
      }
    ]

    planner = Planner.new(actions)

    assert {:ok, result} =
             Engine.execute(:cognition, {:plan, planner},
               initial_state: ["agent_registered"],
               goal_state: ["receipt_minted"]
             )

    assert result.standing == :alive
    assert result.value.plan == ["admit_agent", "construct_workflow", "execute_brce"]
  end

  test "Temporal engine computes Allen's 13 interval relations and LTL constraints" do
    assert {:ok, rel_res} = Engine.execute(:cognition, {:temporal_relate, {{10, 20}, {25, 30}}})
    assert rel_res.value.relation == :before

    trace = ["admit", "construct", "brce", "do", "receipt"]

    assert {:ok, ltl_res1} =
             Engine.execute(:cognition, {:ltl_check, trace},
               formula: {:response, "admit", "receipt"}
             )

    assert ltl_res1.value.satisfied? == true

    assert {:ok, ltl_res2} =
             Engine.execute(:cognition, {:ltl_check, trace},
               formula: {:precedence, "construct", "do"}
             )

    assert ltl_res2.value.satisfied? == true
  end

  test "Pareto dominance multi-objective optimization ranks candidate models" do
    candidates = [
      %{id: "m_fast_low_acc", fitness: 0.7, cost: 5.0},
      %{id: "m_balanced", fitness: 0.9, cost: 10.0},
      %{id: "m_slow_high_acc", fitness: 0.98, cost: 25.0},
      %{id: "m_dominated", fitness: 0.6, cost: 30.0}
    ]

    assert {:ok, result} =
             Engine.execute(:cognition, {:pareto_rank, candidates},
               objectives: [{:fitness, :maximize}, {:cost, :minimize}]
             )

    assert result.standing == :alive
    assert length(result.value.frontier) == 3
    refute Enum.any?(result.value.frontier, &(&1.id == "m_dominated"))
  end

  test "AutoSystems Cost Law evaluates multi-factor cost function" do
    meta = %{duration_ms: 2500, compute_units: 4, risk_factor: 1.2, errors_count: 0}

    assert {:ok, result} = Engine.execute(:cognition, {:cost_evaluate, meta})
    assert result.standing == :alive
    assert result.value.total_cost > 0.0
  end

  test "Adversarial detector identifies false passes and receipt anomalies" do
    log = %Ex4pm.EventLog{
      events: [
        %Ex4pm.Event{
          id: "e1",
          activity: "create",
          timestamp: "2026-01-01T12:00:00Z",
          object_ids: ["unregistered_obj_99"]
        }
      ],
      objects: %{"obj_1" => %Ex4pm.ObjectRef{id: "obj_1", type: "Order"}},
      object_relationships: [],
      subject: %Ex4pm.Subject{kind: :event_log, hash: "invalid_hash"}
    }

    assert {:ok, result} = Engine.execute(:cognition, {:adversarial_audit, log})
    assert result.standing == :blocked
    assert result.value.passed? == false
    assert result.value.violations_count >= 2
  end

  test "InterviewAssist active inquiry protocol evaluates option choices" do
    question = %Interview.Question{
      id: "q1",
      prompt: "Select target deployment tier",
      options: ["production", "staging", "dev"]
    }

    assert {:ok, result} =
             Engine.execute(:cognition, {:interview_evaluate, {question, "production"}})

    assert result.standing == :alive
    assert result.value.accepted? == true
    assert result.value.ambiguity_reduction > 0.3
  end
end
