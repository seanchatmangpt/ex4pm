defmodule Ex4pm.EngineFerroplanTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.Ferroplan
  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  # The bundled, MANIFEST-pinned artifact shipped in priv/.
  @artifact Path.expand("../priv/ferroplan/ferroplan_wasm.wasm", __DIR__)
  @fixtures Path.expand("support/fixtures/ferroplan", __DIR__)

  defp fixture(name), do: File.read!(Path.join(@fixtures, name))

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

  defp opts do
    digest = :crypto.hash(:sha256, File.read!(@artifact)) |> Base.encode16(case: :lower)
    [ferroplan_artifact: @artifact, ferroplan_expected_sha256: digest]
  end

  test "facade arity contract" do
    for {f, a} <- [plan: 4, plan_production: 4, readiness: 1, version: 1, wasm_built?: 0] do
      assert function_exported?(Ferroplan, f, a), "missing #{f}/#{a}"
    end

    assert Ferroplan.id() == :ferroplan

    for {f, a} <- [
          hierarchical_plan: 3,
          fond_policy: 3,
          hddl_solve: 4,
          fond_policy_validate: 3,
          fond_validate: 3,
          explain: 4
        ] do
      assert function_exported?(Ferroplan, f, a), "missing #{f}/#{a}"
    end

    for op <- ~w(ferroplan_hierarchical_plan ferroplan_fond_policy ferroplan_plan
                 ferroplan_plan_production ferroplan_readiness ferroplan_version
                 ferroplan_hddl_solve ferroplan_fond_policy_validate ferroplan_fond_validate
                 ferroplan_explain)a do
      assert Ferroplan.supports?(op, [])
    end

    refute Ferroplan.supports?(:discover, [])
    # bare :plan only when the caller explicitly selects the engine
    refute Ferroplan.supports?(:plan, [])
    assert Ferroplan.supports?(:plan, engine: :ferroplan)
  end

  test "version and readiness really execute" do
    assert {:ok, v} = Ferroplan.version(opts())
    assert is_map(v)
    assert {:ok, r} = Ferroplan.readiness(opts())
    assert is_map(r)
  end

  test "real plan on a small PDDL problem" do
    assert {:ok, sol} = Ferroplan.plan(@domain, @problem, %{}, opts())
    assert is_map(sol)
    assert sol["solved"] == true

    assert [%{"action" => "GO", "args" => ["A", "B"]}, %{"args" => ["B", "C"]}] =
             sol["plan"]["steps"]
  end

  test "execute returns alive Result with evidence" do
    assert {:ok, %Result{} = r} =
             Ferroplan.execute(:ferroplan_plan, %{domain: @domain, problem: @problem}, opts())

    assert r.engine == :ferroplan
    assert r.standing == :alive
    assert r.evidence.executed == true
    assert r.evidence.wasm_sha256 == Keyword.fetch!(opts(), :ferroplan_expected_sha256)
    assert Ferroplan.available?(opts())
  end

  test "typed refusal on bad input" do
    assert {:error, %Refusal{code: :ferroplan_bad_input}} =
             Ferroplan.plan(:nope, "x", %{}, opts())

    assert {:error, %Refusal{code: :ferroplan_bad_input}} =
             Ferroplan.execute(:ferroplan_plan, %{domain: 1}, opts())

    assert {:error, %Refusal{code: :ferroplan_engine_error}} =
             Ferroplan.plan("(not pddl", "(also not", %{}, opts())
  end

  test "typed refusal on missing artifact and digest mismatch" do
    missing = [ferroplan_artifact: "/nonexistent/ferroplan.wasm"]
    refute Ferroplan.available?(missing)
    refute Ferroplan.wasm_built?(missing)
    assert {:error, %Refusal{code: :ferroplan_artifact_missing}} = Ferroplan.version(missing)

    assert {:error, %Refusal{code: :ferroplan_artifact_missing}} =
             Ferroplan.execute(:ferroplan_version, %{}, missing)

    bad = Keyword.put(opts(), :ferroplan_expected_sha256, String.duplicate("0", 64))
    refute Ferroplan.available?(bad)
    assert {:error, %Refusal{code: :ferroplan_digest_mismatch}} = Ferroplan.version(bad)
  end

  test "plan_production is candidate-only (partial_alive)" do
    assert {:ok, %Result{} = r} =
             Ferroplan.execute(
               :ferroplan_plan_production,
               %{domain: @domain, problem: @problem},
               opts()
             )

    assert r.standing == :partial_alive
    assert r.evidence.executed == true
    assert r.evidence.candidate_only == true
  end

  test "bare :plan executes through the engine when engine: :ferroplan" do
    assert {:ok, %Result{} = r} =
             Ex4pm.Engine.execute(
               :plan,
               %{domain: @domain, problem: @problem},
               [engine: :ferroplan] ++ opts()
             )

    assert r.engine == :ferroplan
    assert r.value["solved"] == true
  end

  test "real PDDL fixture (logistics) solves" do
    assert {:ok, sol} =
             Ferroplan.plan(
               fixture("logistics_domain.pddl"),
               fixture("logistics_p1.pddl"),
               %{},
               opts()
             )

    assert sol["solved"] == true
    assert sol["plan"]["steps"] != []
  end

  test "explain returns causal structure for a real plan" do
    {:ok, sol} = Ferroplan.plan(@domain, @problem, %{}, opts())
    assert {:ok, ex} = Ferroplan.explain(@domain, @problem, sol["plan"], opts())
    assert is_map(ex)
    assert Map.has_key?(ex, "causal_links")

    assert {:ok, %Result{} = r} =
             Ferroplan.execute(
               :ferroplan_explain,
               %{domain: @domain, problem: @problem, plan: sol["plan"]},
               opts()
             )

    assert r.standing == :alive
    assert Map.has_key?(r.value, "causal_links")

    assert {:error, %Refusal{code: :ferroplan_bad_input}} =
             Ferroplan.explain(@domain, @problem, :nope, opts())
  end

  test "fond_policy synthesizes a strong-cyclic policy; both validators accept it" do
    problem = fixture("retry_loop_problem.json")
    assert {:ok, pol} = Ferroplan.fond_policy(problem, %{"max_wall_ms" => 0}, opts())
    assert pol["solved"] == true
    assert pol["planning_type"] == "fond"
    assert is_map(pol["validation"])

    for f <- [&Ferroplan.fond_policy_validate/3, &Ferroplan.fond_validate/3] do
      assert {:ok, report} = f.(problem, Map.delete(pol, "validation"), opts())
      assert report["valid"] == true
      assert is_binary(report["guarantee"]) or is_map(report["guarantee"])
    end

    # map problem form is equivalent to JSON text
    assert {:ok, %{"solved" => true}} =
             Ferroplan.fond_policy(Jason.decode!(problem), %{"max_wall_ms" => 0}, opts())

    assert {:ok, %Result{standing: :alive} = r} =
             Ferroplan.execute(
               :ferroplan_fond_policy_validate,
               %{problem: problem, plan: Map.delete(pol, "validation")},
               opts()
             )

    assert r.value["valid"] == true
    assert r.algorithm == :fond_policy_validate

    assert {:ok, %Result{standing: :alive}} =
             Ferroplan.execute(
               :ferroplan_fond_policy,
               %{problem: problem, limits: %{"max_wall_ms" => 0}},
               opts()
             )
  end

  test "fond_policy_validate judges an edited (empty) policy invalid" do
    problem = fixture("retry_loop_problem.json")
    {:ok, pol} = Ferroplan.fond_policy(problem, %{"max_wall_ms" => 0}, opts())
    broken = pol |> Map.delete("validation") |> Map.put("policy", [])
    assert {:ok, report} = Ferroplan.fond_policy_validate(problem, broken, opts())
    assert report["valid"] == false
  end

  test "htn_plan takes problem+limits only (no domain) and really executes" do
    problem = fixture("retry_loop_problem.json")

    assert {:ok, %Result{} = r} =
             Ferroplan.execute(
               :ferroplan_hierarchical_plan,
               %{problem: problem, limits: %{"max_wall_ms" => 0}},
               opts()
             )

    assert r.evidence.executed == true
    assert is_map(r.value)

    assert {:error, %Refusal{code: :ferroplan_bad_input}} =
             Ferroplan.hierarchical_plan(42, nil, opts())
  end

  test "hddl_solve solves a FOND-HTN fixture through facade and Engine.execute" do
    domain = fixture("transport_oneof_domain.hddl")
    problem = fixture("transport_oneof_problem.hddl")

    assert {:ok, plan} = Ferroplan.hddl_solve(domain, problem, %{"max_wall_ms" => 0}, opts())
    assert plan["solved"] == true
    assert plan["planning_type"] == "fond"
    assert plan["policy"] != []

    assert {:ok, %Result{} = r} =
             Ferroplan.execute(:ferroplan_hddl_solve, %{domain: domain, problem: problem}, opts())

    assert r.standing == :alive
    assert r.value["solved"] == true

    assert {:error, _} = Ferroplan.hddl_solve("(not hddl", "(nope", nil, opts())
  end

  test "unsupported operation is refused" do
    assert {:error, %Refusal{code: :ferroplan_unsupported_operation}} =
             Ferroplan.execute(:discover, %{}, opts())
  end
end
