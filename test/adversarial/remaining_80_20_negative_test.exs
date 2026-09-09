defmodule Ex4pmEngine.Adversarial.Remaining8020NegativeTest do
  @moduledoc """
  Negative Test Suite covering the remaining global 80/20 enterprise failure modes:
  1. Receipt hash tampering & forgery rejection (Evidence Replay verification).
  2. Malformed / corrupted NDJSON stream isolation (StreamingEngine fault tolerance).
  3. OCPQ query resilience on missing / dangling object relations.
  4. CPM disjoint & single-node task scheduling.
  5. Survival analysis edge conditions (zero/negative durations, extreme extrapolations).
  6. Bayesian belief propagation under boundary conditions.
  7. POWL invalid node lookup resilience.
  """

  use ExUnit.Case, async: true

  alias Ex4pm.EventLog
  alias Ex4pm.Evidence.{Receipt, Replay}
  alias Ex4pmEngine.StreamingEngine
  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.Cognition.{BayesianNetwork, CriticalPath, Ocpq, Survival}
  alias Ex4pmEngine.Cognition.CriticalPath.Task, as: CpmTask
  alias Ex4pmEngine.Cognition.Ocpq.{BindingBox, QueryTree, VarDecl}

  describe "1. Cryptographic Receipt Tampering & Replay Forgery" do
    test "tampered receipt artifact hash is detected as replay forgery" do
      pending = Receipt.pending("sha256:sub", :transfer_funds, %{id: "admin"})
      outcome = Receipt.outcome(pending, %{status: :ok, amount: 500}, :alive)

      # Replay verify authentic receipt
      assert {:ok, %{replay: :match, standing: :alive}} = Replay.verify(outcome)

      # Tamper with outcome receipt: modify hash without recalculating signature
      forged_receipt = %{
        outcome
        | hash: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
      }

      assert {:error, %Ex4pm.Refusal{code: :replay_mismatch}} = Replay.verify(forged_receipt)
    end
  end

  describe "2. Malformed & Corrupted Streaming Ingest Isolation" do
    test "StreamingEngine skips malformed JSON chunks without crashing the stream pipeline" do
      tmp_path =
        Path.join(
          System.tmp_dir!(),
          "malformed_stream_#{System.unique_integer([:positive])}.ndjson"
        )

      malformed_content = """
      {"ocel:eid": "ev1", "ocel:activity": "login", "ocel:timestamp": "2026-08-22T08:00:00Z", "ocel:omap": ["u1"]}
      {THIS IS CORRUPTED INVALID JSON LINE}
      {"ocel:eid": "ev2", "ocel:activity": "transfer", "ocel:timestamp": "2026-08-22T08:01:00Z", "ocel:omap": ["u1", "acc2"]}
      {"truncated_json_object":
      {"ocel:eid": "ev3", "ocel:activity": "logout", "ocel:timestamp": "2026-08-22T08:02:00Z", "ocel:omap": ["u1"]}
      """

      File.write!(tmp_path, malformed_content)

      # Ingest should successfully parse the 3 valid lines and gracefully skip the 2 corrupted ones
      stats = StreamingEngine.process_file(tmp_path)
      assert stats.total_events == 3
      assert stats.unique_activities == 3

      File.rm(tmp_path)
    end
  end

  describe "3. OCPQ Invariant Queries on Missing & Dangling Relations" do
    test "evaluating query over missing objects returns 0 false-positive passes" do
      root_box = %BindingBox{
        vars: [%VarDecl{name: "c", kind: :object, types: ["customer"]}],
        predicates: []
      }

      child_box = %BindingBox{
        vars: [
          %VarDecl{name: "e", kind: :event, types: ["purchase"]}
        ],
        predicates: [
          {:e2o, "e", "c", nil}
        ]
      }

      # Child tree requires at least 1 purchase child per customer
      child_tree = %QueryTree{
        root_box: child_box,
        min_children: 1,
        max_children: :infinity
      }

      tree = %QueryTree{
        root_box: root_box,
        children: [child_tree]
      }

      # EventLog containing only a customer object without any purchase events
      log = %EventLog{
        subject: %Ex4pm.Subject{id: "sparse_log", kind: :log, hash: "sha256:000"},
        events: [],
        objects: %{
          "cust_1" => %Ex4pm.ObjectRef{id: "cust_1", type: "customer", attributes: %{}}
        },
        object_relationships: []
      }

      result = Ocpq.evaluate_query(log, tree)
      assert result.total_root_bindings == 1
      assert result.violations_count == 1
      assert result.satisfied? == false
    end
  end

  describe "4. Critical Path Method (CPM) DAG Resilience" do
    test "schedules disjoint and single-node task graphs correctly" do
      # Single-node graph
      single_task = [%CpmTask{id: "task_1", duration_ms: 150, dependencies: []}]
      result = CriticalPath.analyze_schedule(single_task)

      assert result.total_duration_ms == 150
      assert result.critical_path == ["task_1"]

      # Disjoint graph (2 independent parallel tasks)
      disjoint_tasks = [
        %CpmTask{id: "task_a", duration_ms: 100, dependencies: []},
        %CpmTask{id: "task_b", duration_ms: 250, dependencies: []}
      ]

      result_disjoint = CriticalPath.analyze_schedule(disjoint_tasks)
      assert result_disjoint.total_duration_ms == 250
      assert result_disjoint.critical_path == ["task_b"]
    end
  end

  describe "5. Kaplan-Meier Survival Analysis Edge Extrapolations" do
    test "predicts safe upper/lower bounds for duration 0 and extreme future durations" do
      durations = [1000, 2000, 3000, 4000, 5000]
      model = Survival.fit_kaplan_meier(durations)

      # At elapsed time 0, remaining time should be approximately median (3000)
      pred_zero = Survival.predict_remaining_time(model, 0)
      assert pred_zero.expected_remaining_ms >= 1000 and pred_zero.expected_remaining_ms <= 5000

      # At elapsed time far beyond max (e.g. 50,000), remaining time should gracefully decay to 0
      pred_extreme = Survival.predict_remaining_time(model, 50_000)
      assert pred_extreme.expected_remaining_ms == 0
    end
  end

  describe "6. Bayesian Belief Propagation Under Boundary Conditions" do
    test "computes consistent marginals when evidence is unobserved" do
      cpts = %{
        "SecurityCheck" => %{"failed" => 0.05, "passed" => 0.95},
        "Reject" => %{
          %{"SecurityCheck" => "failed"} => %{"true" => 0.90, "false" => 0.10},
          %{"SecurityCheck" => "passed"} => %{"true" => 0.01, "false" => 0.99}
        }
      }

      bn = BayesianNetwork.new(["SecurityCheck", "Reject"], cpts)

      # Query without evidence returns prior marginals
      assert {:ok, res_prior} = BayesianNetwork.infer(bn, "Reject", %{})
      assert res_prior.distribution["true"] > 0.0 and res_prior.distribution["true"] < 1.0

      # Query with positive evidence (SecurityCheck = failed) significantly increases Reject probability
      assert {:ok, res_failed} =
               BayesianNetwork.infer(bn, "Reject", %{"SecurityCheck" => "failed"})

      assert res_failed.distribution["true"] > res_prior.distribution["true"]
    end
  end

  describe "7. POWL Structural Lookup Resilience" do
    test "POWL.new returns error when designated root id does not exist in nodes map" do
      act1 = POWL.activity("act1", "Submit")
      nodes = %{"act1" => act1}

      assert {:error, :root_not_found} = POWL.new(nodes, root: "missing_root_node")
    end
  end
end
