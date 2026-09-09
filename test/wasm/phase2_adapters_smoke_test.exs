defmodule Ex4pmEngine.Wasm.Phase2AdaptersSmokeTest do
  @moduledoc """
  Contract-shape coverage for the 8 Phase-2 wasm4pm-ex4pm-bindings adapters
  (survival, markov, bayesian, ocpq_eval, strips_plan, htn_plan, ctl_check,
  allen_temporal) — each a thin wrapper over an already-implemented
  algorithm elsewhere in the wasm4pm workspace (miniml-core / ocpq /
  wasm4pm-cognition), per `Ex4pmEngine.Wasm.Adapter`'s shared six-state
  standing macro. `Ex4pmEngine.Wasm.DiscoverTest` (Phase 1) already carries
  the full ALIVE/PARTIAL_ALIVE/typed-refusal matrix for that macro; these
  tests confirm each concrete module wires its own algorithm_id/engine_id/
  export names correctly, mirroring `AdaptersSmokeTest`'s Phase-1 shape.
  """

  use ExUnit.Case, async: true

  alias Ex4pmEngine.Wasm.{
    AllenTemporal,
    Bayesian,
    CtlCheck,
    HtnPlan,
    Markov,
    OcpqEval,
    StripsPlan,
    Survival
  }

  defp response_for(module, algorithm_id, result) do
    %{
      "standing" => "ALIVE",
      "result" => result,
      "receipt" => %{
        "schema" => module.protocol(),
        "algorithm_id" => to_string(algorithm_id),
        "wasm_export" => module.wasm_export(),
        "wasm4pm_source_sha" => module.wasm4pm_source_sha(),
        "request_digest" => "request-digest",
        "result_digest" => "result-digest"
      }
    }
  end

  defp exact_identity(module) do
    %{
      observed: true,
      wasm4pm_source_sha: module.wasm4pm_source_sha(),
      wasm_sha256: "sha256:observed-wasm",
      replay_verified: true
    }
  end

  test "survival: id/supports?/alive path" do
    assert Survival.id() == :wasm_survival
    assert Survival.supports?(:survival, [])

    subject = %{times: [1.0, 2.0], events: [1.0, 1.0]}
    result_body = %{"survival" => [0.5], "median_survival" => 2.0}

    transport = fn _r, _o ->
      {:ok, response_for(Survival, :survival, result_body), exact_identity(Survival)}
    end

    assert {:ok, result} = Survival.execute(:survival, subject, survival_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_survival
  end

  test "markov: id/supports?/alive path" do
    assert Markov.id() == :wasm_markov
    assert Markov.supports?(:markov, [])

    subject = %{transition_matrix: [0.5, 0.5, 0.5, 0.5], n_states: 2, max_iter: 100, tol: 1.0e-9}
    result_body = %{"steady_state" => [0.5, 0.5]}

    transport = fn _r, _o ->
      {:ok, response_for(Markov, :markov, result_body), exact_identity(Markov)}
    end

    assert {:ok, result} = Markov.execute(:markov, subject, markov_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_markov
  end

  test "bayesian: id/supports?/alive path" do
    assert Bayesian.id() == :wasm_bayesian
    assert Bayesian.supports?(:bayesian, [])

    subject = %{data: [1.0, 2.0], n_features: 1, targets: [2.0, 4.0]}
    result_body = %{"coefficients" => [2.0], "intercept" => 0.0}

    transport = fn _r, _o ->
      {:ok, response_for(Bayesian, :bayesian, result_body), exact_identity(Bayesian)}
    end

    assert {:ok, result} = Bayesian.execute(:bayesian, subject, bayesian_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_bayesian
  end

  test "ocpq_eval: id/supports?/alive path" do
    assert OcpqEval.id() == :wasm_ocpq_eval
    assert OcpqEval.supports?(:ocpq_eval, [])

    subject = %{
      query: %{root: "n0", nodes: [%{id: "n0", box: %{}}]},
      ocel: %{objectTypes: [], eventTypes: [], objects: [], events: []}
    }

    result_body = %{"satisfied" => true}

    transport = fn _r, _o ->
      {:ok, response_for(OcpqEval, :ocpq_eval, result_body), exact_identity(OcpqEval)}
    end

    assert {:ok, result} = OcpqEval.execute(:ocpq_eval, subject, ocpq_eval_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_ocpq_eval
  end

  test "strips_plan: id/supports?/alive path" do
    assert StripsPlan.id() == :wasm_strips_plan
    assert StripsPlan.supports?(:strips_plan, [])

    subject = %{
      intent: "test",
      candidates: [],
      facts: [],
      cases: [],
      rules: [],
      goals: [],
      state: []
    }

    result_body = %{"breed" => "Strips", "explanation" => "no goals"}

    transport = fn _r, _o ->
      {:ok, response_for(StripsPlan, :strips_plan, result_body), exact_identity(StripsPlan)}
    end

    assert {:ok, result} =
             StripsPlan.execute(:strips_plan, subject, strips_plan_wasm_fun: transport)

    assert result.standing == :alive
    assert result.engine == :wasm_strips_plan
  end

  test "htn_plan: id/supports?/alive path" do
    assert HtnPlan.id() == :wasm_htn_plan
    assert HtnPlan.supports?(:htn_plan, [])

    subject = %{
      intent: "test",
      candidates: [],
      facts: [],
      cases: [],
      rules: [],
      goals: [],
      state: []
    }

    result_body = %{"breed" => "HtnPlanning", "explanation" => "no goals"}

    transport = fn _r, _o ->
      {:ok, response_for(HtnPlan, :htn_plan, result_body), exact_identity(HtnPlan)}
    end

    assert {:ok, result} = HtnPlan.execute(:htn_plan, subject, htn_plan_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_htn_plan
  end

  test "ctl_check: id/supports?/alive path" do
    assert CtlCheck.id() == :wasm_ctl_check
    assert CtlCheck.supports?(:ctl_check, [])

    subject = %{
      intent: "test",
      candidates: [],
      cases: [],
      rules: [],
      goals: [],
      state: [],
      facts: [
        %{key: "ts:init", value: "s0"},
        %{key: "ts:edge:s0", value: "s1"},
        %{key: "ctl:formula", value: "E F s1"}
      ]
    }

    result_body = %{"breed" => "CtlCheck", "explanation" => "formula holds"}

    transport = fn _r, _o ->
      {:ok, response_for(CtlCheck, :ctl_check, result_body), exact_identity(CtlCheck)}
    end

    assert {:ok, result} = CtlCheck.execute(:ctl_check, subject, ctl_check_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_ctl_check
  end

  test "allen_temporal: id/supports?/alive path" do
    assert AllenTemporal.id() == :wasm_allen_temporal
    assert AllenTemporal.supports?(:allen_temporal, [])

    subject = %{
      intent: "test",
      candidates: [],
      facts: [],
      cases: [],
      rules: [],
      goals: [],
      state: []
    }

    result_body = %{"breed" => "AllenTemporal", "explanation" => "no intervals"}

    transport = fn _r, _o ->
      {:ok, response_for(AllenTemporal, :allen_temporal, result_body),
       exact_identity(AllenTemporal)}
    end

    assert {:ok, result} =
             AllenTemporal.execute(:allen_temporal, subject, allen_temporal_wasm_fun: transport)

    assert result.standing == :alive
    assert result.engine == :wasm_allen_temporal
  end
end
