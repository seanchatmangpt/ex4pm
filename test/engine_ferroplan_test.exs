defmodule Ex4pm.EngineFerroplanTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.Ferroplan
  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  @artifact Application.compile_env(
              :ex4pm,
              :ferroplan_test_artifact,
              "/Users/sac/ferroplan/target/wasm32-wasip1/release/ferroplan_wasm.wasm"
            )

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

    for op <- ~w(ferroplan_hierarchical_plan ferroplan_fond_policy ferroplan_plan
                 ferroplan_plan_production ferroplan_readiness ferroplan_version)a do
      assert Ferroplan.supports?(op, [])
    end

    refute Ferroplan.supports?(:discover, [])
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
    assert [%{"action" => "GO", "args" => ["A", "B"]}, %{"args" => ["B", "C"]}] = sol["plan"]["steps"]
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
    assert {:error, %Refusal{code: :ferroplan_bad_input}} = Ferroplan.plan(:nope, "x", %{}, opts())

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

  test "plan_production is candidate-only (partial_alive), fond_policy_validate unsupported" do
    assert {:ok, %Result{} = r} =
             Ferroplan.execute(:ferroplan_plan_production, %{domain: @domain, problem: @problem}, opts())

    assert r.standing == :partial_alive
    assert r.evidence.executed == true
    assert r.evidence.candidate_only == true

    assert {:error, %Refusal{code: :ferroplan_unsupported_operation}} =
             Ferroplan.execute(:ferroplan_fond_policy_validate, %{}, opts())
  end

  test "unsupported operation is refused" do
    assert {:error, %Refusal{code: :ferroplan_unsupported_operation}} =
             Ferroplan.execute(:discover, %{}, opts())
  end
end
