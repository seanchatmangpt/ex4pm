defmodule Ex4pm.PublicApiTest do
  @moduledoc """
  Chicago tests for the wasm4pm / ferroplan public surface: real bundled artifacts, real
  receipts in the real evidence store, no doubles.
  """
  use ExUnit.Case, async: false

  alias Ex4pm.Refusal
  alias Ex4pm.Run
  alias Ex4pm.Test.WasmArtifact

  @ferroplan_artifact Path.expand("../priv/ferroplan/ferroplan_wasm.wasm", __DIR__)

  @domain """
  (define (domain move)
    (:requirements :strips)
    (:predicates (at ?x) (link ?x ?y))
    (:action go
      :parameters (?from ?to)
      :precondition (and (at ?from) (link ?from ?to))
      :effect (and (at ?to) (not (at ?from)))))
  """

  @problem """
  (define (problem p1)
    (:domain move)
    (:objects a b c)
    (:init (at a) (link a b) (link b c))
    (:goal (at c)))
  """

  @stats ~w(mean median percentile std_deviation standardize dot_product euclidean_distance
            ks_statistic ks_critical_value regression forecast holt_forecast ewma
            trend_classify)a

  describe "statistics/3" do
    test "all 14 ops execute on the real wasm artifact and produce replayable receipts" do
      requests = WasmArtifact.canonical_requests()

      for op <- @stats do
        assert {:ok, %Run{} = run} = Ex4pm.statistics(op, Map.fetch!(requests, op))
        assert run.operation == op
        assert run.standing in [:alive, :partial_alive]
        assert run.engine_result.engine == :"wasm_#{op}"
        assert is_map(run.value)
        assert {:ok, _verified} = Ex4pm.replay(run.receipt.hash)
      end
    end

    test "list and tuple data are shaped into the wasm request" do
      assert {:ok, run} = Ex4pm.statistics(:mean, [1.0, 2.0, 3.0, 4.0])
      assert inspect(run.value) =~ "2.5"

      assert {:ok, run} = Ex4pm.statistics(:euclidean_distance, {[0.0, 0.0], [3.0, 4.0]})
      assert inspect(run.value) =~ "5.0"

      assert {:ok, run} = Ex4pm.statistics(:percentile, [1.0, 2.0, 3.0, 4.0], p: 50.0)
      assert run.standing in [:alive, :partial_alive]
    end

    test "typed refusals for unknown op and wrong data shape" do
      assert {:error, %Refusal{code: :unsupported_statistics_operation}} =
               Ex4pm.statistics(:nonsense, [1.0])

      assert {:error, %Refusal{code: :invalid_statistics_input}} =
               Ex4pm.statistics(:dot_product, [1.0, 2.0])
    end

    test "an engine blocked by wasm_default: false is a typed refusal, not a fallback" do
      assert {:error, %Refusal{code: :engine_blocked}} =
               Ex4pm.statistics(:mean, [1.0], wasm_default: false)
    end
  end

  describe "forecast/2" do
    test "forecast, holt and ewma methods execute" do
      series = [1.0, 2.0, 3.0, 4.0, 5.0]

      for {method, op} <- [forecast: :forecast, holt: :holt_forecast, ewma: :ewma] do
        assert {:ok, run} = Ex4pm.forecast(series, method: method, alpha: 0.5)
        assert run.operation == op
        assert run.standing in [:alive, :partial_alive]
      end
    end

    test "default method is :forecast; unknown method is refused" do
      assert {:ok, %Run{operation: :forecast}} = Ex4pm.forecast([1.0, 2.0, 3.0])

      assert {:error, %Refusal{code: :invalid_forecast_method}} =
               Ex4pm.forecast([1.0], method: :arima)
    end
  end

  describe "wasm/1" do
    test "lists the 33 algorithm engines with standing" do
      engines = Ex4pm.wasm()
      assert length(engines) == 33
      assert Enum.all?(engines, &(&1.standing == :partial_alive and &1.executed == false))
      assert Enum.any?(engines, &(&1.id == :wasm_forecast))
    end

    test "is blocked when transports are disabled" do
      assert Enum.all?(Ex4pm.wasm(wasm_default: false), &(&1.standing == :blocked))
    end
  end

  describe "health/1" do
    test "reports both artifacts ALIVE after executed probes" do
      health = Ex4pm.health()
      assert health.standing == :alive

      w = health.wasm4pm
      assert w.artifact_present and w.admitted
      assert w.sha256 == WasmArtifact.sha256()
      assert w.sha256 == w.pin_sha256
      assert w.missing_exports == []
      assert w.probe == :ok
      assert is_binary(w.source_sha) and is_binary(w.protocol)

      f = health.ferroplan
      assert f.artifact_present and f.admitted and f.probe == :ok
      assert is_binary(f.version)
      assert f.sha256 == f.pin_sha256
    end

    test "probe: false is inspection only (partial_alive)" do
      health = Ex4pm.health(probe: false)
      assert health.standing == :partial_alive
      assert health.wasm4pm.probe == :skipped
      assert health.ferroplan.probe == :skipped
    end

    test "missing artifacts are blocked" do
      health =
        Ex4pm.health(
          artifact_path: "/nonexistent/wasm4pm.wasm",
          ferroplan_artifact: "/nonexistent/ferroplan.wasm"
        )

      assert health.standing == :blocked
      assert health.wasm4pm.refusal == :wasm_artifact_missing
      refute health.wasm4pm.artifact_present
      refute health.ferroplan.artifact_present
    end
  end

  describe "ferroplan/3" do
    test "version and readiness execute as receipted runs" do
      assert {:ok, %Run{standing: :alive} = run} = Ex4pm.ferroplan(:version)
      assert is_binary(run.value["version"])
      assert {:ok, _} = Ex4pm.replay(run.receipt.hash)

      assert {:ok, %Run{standing: :alive}} = Ex4pm.ferroplan(:readiness)
    end

    test "plan solves a PDDL problem" do
      assert {:ok, run} = Ex4pm.ferroplan(:plan, %{domain: @domain, problem: @problem})
      assert run.operation == :ferroplan_plan
      assert run.value["solved"] == true
      assert run.engine_result.engine == :ferroplan
    end

    test "plan_production is candidate-only (partial_alive)" do
      assert {:ok, %Run{standing: :partial_alive}} =
               Ex4pm.ferroplan(:plan_production, %{domain: @domain, problem: @problem})
    end

    test "hddl_solve runs on the HDDL fixtures" do
      fixtures = Path.expand("support/fixtures/ferroplan", __DIR__)

      subject = %{
        domain: File.read!(Path.join(fixtures, "transport_oneof_domain.hddl")),
        problem: File.read!(Path.join(fixtures, "transport_oneof_problem.hddl"))
      }

      assert {:ok, %Run{operation: :ferroplan_hddl_solve}} = Ex4pm.ferroplan(:hddl_solve, subject)
    end

    test "typed refusals (an unadmitted or absent artifact is :engine_blocked)" do
      assert {:error, %Refusal{code: :ferroplan_unsupported_operation}} =
               Ex4pm.ferroplan(:session_new, %{})

      assert {:error, %Refusal{code: :ferroplan_bad_input}} = Ex4pm.ferroplan(:plan, %{})
      assert {:error, %Refusal{code: :ferroplan_bad_input}} = Ex4pm.ferroplan(:plan, "text")

      assert {:error, %Refusal{code: :engine_blocked}} =
               Ex4pm.ferroplan(:version, %{},
                 ferroplan_artifact: @ferroplan_artifact,
                 ferroplan_expected_sha256: String.duplicate("0", 64)
               )

      assert {:error, %Refusal{code: :engine_blocked}} =
               Ex4pm.ferroplan(:version, %{}, ferroplan_artifact: "/nonexistent/f.wasm")
    end
  end

  describe "plan/2 routing" do
    test "PDDL text routes to ferroplan" do
      assert {:ok, run} = Ex4pm.plan(%{domain: @domain, problem: @problem})
      assert run.engine_result.engine == :ferroplan
      assert run.value["solved"] == true
    end

    test "explicit engine: :ferroplan routes to ferroplan" do
      assert {:ok, run} =
               Ex4pm.plan(%{"domain" => @domain, "problem" => @problem}, engine: :ferroplan)

      assert run.engine_result.engine == :ferroplan
    end

    test "engine: :wasm_strips_plan and :wasm_htn_plan route to the wasm planners" do
      requests = WasmArtifact.canonical_requests()

      assert {:ok, run} = Ex4pm.plan(requests.strips_plan, engine: :wasm_strips_plan)
      assert run.operation == :strips_plan
      assert run.engine_result.engine == :wasm_strips_plan

      assert {:ok, run} = Ex4pm.plan(requests.htn_plan, engine: :wasm_htn_plan)
      assert run.operation == :htn_plan
    end

    test "a non-PDDL problem keeps the :ex4pm_plan default and its blocked refusal" do
      assert {:error, %Refusal{code: :engine_blocked}} =
               Ex4pm.plan(%{type: :deterministic_graph, initial: "A", goals: ["G"], edges: []})

      assert {:error, %Refusal{code: :invalid_planning_problem}} = Ex4pm.plan("not a map")
    end
  end
end
