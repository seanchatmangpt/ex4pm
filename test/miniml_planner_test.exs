defmodule Ex4pm.Engine.MinimlPlannerTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Cognition.{
    Causal,
    CriticalPath,
    CriticalPath.Task,
    Markov,
    Survival
  }

  test "Survival Analysis fits Kaplan-Meier curve and predicts remaining time" do
    durations = [1000, 1500, 2000, 2500, 3000, 4000, 5000]

    model = Survival.fit_kaplan_meier(durations)
    assert model.sample_size == 7
    assert model.median_duration_ms == 2500

    prediction = Survival.predict_remaining_time(model, 1200)
    assert prediction.expected_remaining_ms == 1300
    assert prediction.risk_of_exceeding_median? == false
  end

  test "Causal Discovery infers directly-follows dependency scores" do
    traces = %{
      "case_1" => ["admit", "construct", "brce", "do", "receipt"],
      "case_2" => ["admit", "construct", "brce", "do", "receipt"],
      "case_3" => ["admit", "construct", "refuse"]
    }

    causal = Causal.infer_causal_dependencies(traces)
    assert map_size(causal.strong_causal_edges) >= 3
    assert Map.get(causal.strong_causal_edges, {"admit", "construct"}) > 0.6
  end

  test "Markov Chain models state transitions and probabilities" do
    traces = [
      ["start", "step_a", "finish"],
      ["start", "step_a", "finish"],
      ["start", "step_b", "finish"]
    ]

    markov = Markov.fit_markov_chain(traces)
    assert Markov.transition_prob(markov, "start", "step_a") == 0.6667
    assert Markov.transition_prob(markov, "start", "step_b") == 0.3333
  end

  test "Critical Path Method determines earliest/latest start and slack" do
    tasks = [
      %Task{id: "A", duration_ms: 10, dependencies: []},
      %Task{id: "B", duration_ms: 20, dependencies: ["A"]},
      %Task{id: "C", duration_ms: 5, dependencies: ["A"]},
      %Task{id: "D", duration_ms: 15, dependencies: ["B", "C"]}
    ]

    cpm = CriticalPath.analyze_schedule(tasks)
    assert cpm.total_duration_ms == 45
    assert cpm.critical_path == ["A", "B", "D"]
    assert cpm.task_schedules["C"].slack == 15
    assert cpm.task_schedules["C"].critical? == false
  end
end
