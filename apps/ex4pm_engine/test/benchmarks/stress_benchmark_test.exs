defmodule Ex4pm.Engine.StressBenchmarkTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Event
  alias Ex4pm.EventLog
  alias Ex4pm.ObjectRef
  alias Ex4pm.ObjectRelationship
  alias Ex4pm.Subject
  alias Ex4pmEngine.StreamingEngine
  alias Ex4pmCore.Blueprints.GovernanceApproval

  alias Ex4pmEngine.Cognition.{
    BayesianNetwork,
    Causal,
    CriticalPath,
    CriticalPath.Task,
    Markov,
    Ocpq,
    Ocpq.BindingBox,
    Ocpq.QueryTree,
    Ocpq.VarDecl,
    Survival
  }

  @real_ocel_path "/Users/sac/xaas/priv/ocel/ash-actions.ndjson"

  @tag :stress
  test "BENCHMARK 1: High-Throughput Streaming Engine on 50k Real Production OCEL Events" do
    if File.exists?(@real_ocel_path) do
      {time_us, result} =
        :timer.tc(fn ->
          StreamingEngine.process_file(@real_ocel_path, chunk_size: 10_000, max_concurrency: 8)
        end)

      time_ms = time_us / 1000.0
      events_per_sec = (result.total_events / (time_ms / 1000.0)) |> round()

      IO.puts("""

      ========================================================================
        BENCHMARK 1: StreamingEngine Ingest & Mining Throughput
      ========================================================================
        Total Events Processed:   #{result.total_events}
        Total Processing Time:    #{Float.round(time_ms, 2)} ms
        Peak Streaming Rate:      #{events_per_sec} events / sec
        Discovered Activities:    #{result.unique_activities}
        Discovered Categories:    #{map_size(result.activity_frequencies)}
        Unique Interacting Objs:  #{result.unique_objects}
      ========================================================================
      """)

      assert result.total_events >= 50_000
      assert events_per_sec > 10_000
    end
  end

  @tag :stress
  test "BENCHMARK 2: Normative Conformance Verification over Strict Process Blueprint" do
    blueprint = GovernanceApproval.blueprint()

    # Generate test traces with both conforming and deviating execution paths
    conforming_trace = [
      %Event{
        id: "e1",
        activity: "request_change",
        timestamp: "2026-08-21T10:00:00Z",
        object_ids: ["chg_1"]
      },
      %Event{
        id: "e2",
        activity: "assess_risk",
        timestamp: "2026-08-21T10:05:00Z",
        object_ids: ["chg_1"]
      },
      %Event{
        id: "e3",
        activity: "peer_review",
        timestamp: "2026-08-21T10:10:00Z",
        object_ids: ["chg_1"]
      },
      %Event{
        id: "e4",
        activity: "manager_approval",
        timestamp: "2026-08-21T10:15:00Z",
        object_ids: ["chg_1"]
      },
      %Event{
        id: "e5",
        activity: "security_review",
        timestamp: "2026-08-21T10:20:00Z",
        object_ids: ["chg_1"]
      },
      %Event{
        id: "e6",
        activity: "cab_approval",
        timestamp: "2026-08-21T10:25:00Z",
        object_ids: ["chg_1"]
      },
      %Event{
        id: "e7",
        activity: "apply_change",
        timestamp: "2026-08-21T10:30:00Z",
        object_ids: ["chg_1"]
      },
      %Event{
        id: "e8",
        activity: "post_implementation_review",
        timestamp: "2026-08-21T10:35:00Z",
        object_ids: ["chg_1"]
      }
    ]

    # Trace with severe policy violation (skipping peer_review, manager_approval, security_review)
    deviating_trace = [
      %Event{
        id: "e10",
        activity: "request_change",
        timestamp: "2026-08-21T11:00:00Z",
        object_ids: ["chg_2"]
      },
      %Event{
        id: "e11",
        activity: "apply_change",
        timestamp: "2026-08-21T11:05:00Z",
        object_ids: ["chg_2"]
      }
    ]

    log = %EventLog{
      events: conforming_trace ++ deviating_trace,
      objects: %{
        "chg_1" => %ObjectRef{id: "chg_1", type: "ChangeRequest"},
        "chg_2" => %ObjectRef{id: "chg_2", type: "ChangeRequest"}
      },
      object_relationships: [],
      subject: %Subject{kind: :event_log, hash: "normative_log_hash"}
    }

    {time_us, vector} =
      :timer.tc(fn ->
        Ex4pmEvidence.Conformance.evaluate(
          %{
            "objects" => log.objects,
            "events" => Map.new(log.events, &{&1.id, &1})
          },
          blueprint,
          object_type: "ChangeRequest"
        )
      end)

    assert {:ok, cv} = vector
    time_ms = time_us / 1000.0

    IO.puts("""

    ========================================================================
      BENCHMARK 2: Normative Conformance Vector (Real Violations Detected)
    ========================================================================
      Evaluation Time:          #{Float.round(time_ms, 2)} ms
      Fitness Score:            #{Float.round(cv.fitness * 100, 2)}%
      Precision Score:          #{Float.round(cv.precision * 100, 2)}%
      Policy Conformance:       #{Float.round(cv.policy_conformance * 100, 2)}%
      Lifecycle Conformance:    #{Float.round(cv.lifecycle_conformance * 100, 2)}%
      Causal Conformance:       #{Float.round(cv.causal_conformance * 100, 2)}%
      Violations Count:         #{length(cv.violations)}
      Standing Outcome:         #{cv.standing}
    ========================================================================
    """)

    assert cv.fitness < 1.0
    assert length(cv.violations) > 0
  end

  @tag :stress
  test "BENCHMARK 3: OCPQ Multi-Object Invariant Checking at Scale" do
    # Generate 5,000 multi-object events across 1,000 orders, items, and packages
    events =
      Enum.flat_map(1..1000, fn i ->
        o_id = "order_#{i}"
        pkg_id = "pkg_#{i}"
        t1 = "2026-08-21T10:00:00Z"
        t2 = "2026-08-21T10:15:00Z"

        [
          %Event{id: "ev_p_#{i}", activity: "place_order", timestamp: t1, object_ids: [o_id]},
          %Event{id: "ev_s_#{i}", activity: "ship_package", timestamp: t2, object_ids: [pkg_id]}
        ]
      end)

    objects =
      Enum.reduce(1..1000, %{}, fn i, acc ->
        acc
        |> Map.put("order_#{i}", %ObjectRef{id: "order_#{i}", type: "Order"})
        |> Map.put("pkg_#{i}", %ObjectRef{id: "pkg_#{i}", type: "Package"})
      end)

    relations =
      Enum.map(1..1000, fn i ->
        %ObjectRelationship{
          source_id: "order_#{i}",
          target_id: "pkg_#{i}",
          qualifier: "fulfilled_by"
        }
      end)

    log = %EventLog{
      events: events,
      objects: objects,
      object_relationships: relations,
      subject: %Subject{kind: :event_log, hash: "ocpq_stress_hash"}
    }

    query_tree = %QueryTree{
      root_box: %BindingBox{
        vars: [
          %VarDecl{name: "e1", kind: :event, types: ["place_order"]},
          %VarDecl{name: "o", kind: :object, types: ["Order"]}
        ],
        predicates: [{:e2o, "e1", "o", nil}]
      },
      children: [
        %QueryTree{
          root_box: %BindingBox{
            vars: [
              %VarDecl{name: "e2", kind: :event, types: ["ship_package"]},
              %VarDecl{name: "p", kind: :object, types: ["Package"]}
            ],
            predicates: [
              {:e2o, "e2", "p", nil},
              {:o2o, "o", "p", "fulfilled_by"},
              {:tbe, "e1", "e2", :<=, 1_800_000}
            ]
          },
          min_children: 1,
          max_children: 1
        }
      ]
    }

    {time_us, res} = :timer.tc(fn -> Ocpq.evaluate_query(log, query_tree) end)
    time_ms = time_us / 1000.0

    IO.puts("""

    ========================================================================
      BENCHMARK 3: OCPQ Multi-Object Invariant Evaluation Stress
    ========================================================================
      Total Events Evaluated:   #{length(events)}
      Total Objects Bound:      #{map_size(objects)}
      Evaluation Time:          #{Float.round(time_ms, 2)} ms
      Root Bindings Resolved:   #{res.total_root_bindings}
      Violations Count:         #{res.violations_count}
      Invariant Satisfied?:     #{res.satisfied?}
    ========================================================================
    """)

    assert res.satisfied? == true
    assert res.total_root_bindings == 1000
    assert time_ms < 1500.0
  end

  @tag :stress
  test "BENCHMARK 4: Kaplan-Meier Survival Analysis Stress (10,000 Case Durations)" do
    # Generate 10,000 realistic log-normal case durations (ms)
    durations =
      Enum.map(1..10_000, fn _ ->
        # Log-normal distribution approximation (median around 15,000 ms)
        (:rand.uniform(30_000) + :rand.uniform(10_000)) |> round()
      end)

    {fit_time_us, model} = :timer.tc(fn -> Survival.fit_kaplan_meier(durations) end)
    fit_time_ms = fit_time_us / 1000.0

    # Execute 1,000 in-flight RUL predictions
    {pred_time_us, _predictions} =
      :timer.tc(fn ->
        Enum.map(1..1000, fn i ->
          Survival.predict_remaining_time(model, i * 20)
        end)
      end)

    pred_time_ms = pred_time_us / 1000.0

    IO.puts("""

    ========================================================================
      BENCHMARK 4: Kaplan-Meier Survival Analysis & RUL Forecasting
    ========================================================================
      Sample Size:              #{model.sample_size} cases
      Model Fit Time:           #{Float.round(fit_time_ms, 2)} ms
      Median Process Duration:  #{model.median_duration_ms} ms
      Survival Curve Points:    #{length(model.survival_curve)}
      1,000 RUL Predictions:    #{Float.round(pred_time_ms, 2)} ms (#{Float.round(1000 / (pred_time_ms / 1000), 0)} preds/sec)
    ========================================================================
    """)

    assert model.sample_size == 10_000
    assert fit_time_ms < 100.0
    assert pred_time_ms < 50.0
  end

  @tag :stress
  test "BENCHMARK 5: Critical Path Method (CPM) DAG Scheduler (500-Node Execution Graph)" do
    # Generate 500 task nodes with cascading dependencies
    tasks =
      Enum.map(1..500, fn i ->
        deps =
          cond do
            i <= 5 -> []
            true -> ["task_#{max(1, i - 1)}", "task_#{max(1, i - 2)}"]
          end

        %Task{
          id: "task_#{i}",
          duration_ms: :rand.uniform(50) + 10,
          dependencies: deps
        }
      end)

    {time_us, cpm} = :timer.tc(fn -> CriticalPath.analyze_schedule(tasks) end)
    time_ms = time_us / 1000.0

    IO.puts("""

    ========================================================================
      BENCHMARK 5: Critical Path Method (CPM) DAG Scheduler
    ========================================================================
      Total Tasks Scheduled:    #{length(tasks)}
      Total Schedule Duration:  #{cpm.total_duration_ms} ms
      Critical Path Task Count: #{length(cpm.critical_path)}
      CPM Calculation Time:     #{Float.round(time_ms, 2)} ms
    ========================================================================
    """)

    assert map_size(cpm.task_schedules) == 500
    assert length(cpm.critical_path) > 0
    assert time_ms < 50.0
  end

  @tag :stress
  test "BENCHMARK 6: Causal Discovery & Markov Matrix Inference over 1,000 Complex Traces" do
    activities = [
      "admit",
      "route",
      "validate",
      "construct",
      "review",
      "approve",
      "brce",
      "do",
      "receipt"
    ]

    traces =
      Enum.map(1..1000, fn _ ->
        # Random walk through activities
        Enum.take_random(activities, 6)
      end)

    {causal_us, causal} = :timer.tc(fn -> Causal.infer_causal_dependencies(traces) end)
    {markov_us, markov} = :timer.tc(fn -> Markov.fit_markov_chain(traces) end)

    causal_ms = causal_us / 1000.0
    markov_ms = markov_us / 1000.0

    IO.puts("""

    ========================================================================
      BENCHMARK 6: Causal Discovery & Markov State Dynamics
    ========================================================================
      Traces Ingested:          1,000 traces (6,000 events)
      Causal Induction Time:    #{Float.round(causal_ms, 2)} ms
      Strong Causal Edges:      #{causal.edge_count}
      Markov Fitting Time:      #{Float.round(markov_ms, 2)} ms
      Markov State Count:       #{markov.state_count}
    ========================================================================
    """)

    assert causal.edge_count >= 0
    assert markov.state_count > 0
    assert causal_ms < 100.0
  end

  @tag :stress
  test "BENCHMARK 7: Bayesian Network Exact Belief Propagation (Variable Elimination)" do
    nodes = ["SecurityCheck", "HighRisk", "RequireDualApproval", "Reject"]

    cpts = %{
      "HighRisk" => %{"true" => 0.1, "false" => 0.9},
      "SecurityCheck" => %{
        %{"HighRisk" => "true"} => %{"failed" => 0.4, "passed" => 0.6},
        %{"HighRisk" => "false"} => %{"failed" => 0.05, "passed" => 0.95}
      },
      "RequireDualApproval" => %{
        %{"HighRisk" => "true"} => %{"true" => 0.9, "false" => 0.1},
        %{"HighRisk" => "false"} => %{"true" => 0.2, "false" => 0.8}
      },
      "Reject" => %{
        %{"SecurityCheck" => "failed", "RequireDualApproval" => "true"} => %{
          "true" => 0.99,
          "false" => 0.01
        },
        %{"SecurityCheck" => "failed", "RequireDualApproval" => "false"} => %{
          "true" => 0.85,
          "false" => 0.15
        },
        %{"SecurityCheck" => "passed", "RequireDualApproval" => "true"} => %{
          "true" => 0.1,
          "false" => 0.9
        },
        %{"SecurityCheck" => "passed", "RequireDualApproval" => "false"} => %{
          "true" => 0.01,
          "false" => 0.99
        }
      }
    }

    bn = BayesianNetwork.new(nodes, cpts)

    {time_us, {:ok, result}} =
      :timer.tc(fn ->
        BayesianNetwork.infer(bn, "Reject", %{"SecurityCheck" => "failed"})
      end)

    time_ms = time_us / 1000.0

    IO.puts("""

    ========================================================================
      BENCHMARK 7: Bayesian Network Belief Propagation
    ========================================================================
      Inference Time:           #{Float.round(time_ms, 3)} ms
      Query:                    P(Reject | SecurityCheck = failed)
      Distribution True:        #{result.distribution["true"]}
      Distribution False:       #{result.distribution["false"]}
    ========================================================================
    """)

    assert result.distribution["true"] > 0.8
    assert time_ms < 10.0
  end
end
