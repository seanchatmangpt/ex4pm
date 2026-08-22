defmodule Ex4pm.Engine.Cognition do
  @moduledoc """
  High-level Cognition & AutoSystems dispatcher.
  Coordinates native BEAM cognitive kernels:
  - `:bayesian`: Bayesian Network exact marginalization & inference
  - `:prolog`: Horn-clause resolution & unification
  - `:planner`: STRIPS & HTN action planning
  - `:temporal`: Allen's 13 interval relations & LTL checking
  - `:blackboard`: Hearsay-II blackboard opportunistic reasoning
  - `:pareto`: Multi-objective Pareto frontier ranking
  - `:cost_law`: AutoSystems cost function evaluation
  - `:adversarial`: 8 false-pass integrity audits
  - `:interview`: InterviewAssist active inquiry & qualification
  """

  alias Ex4pm.Engine.Result

  alias Ex4pmEngine.Cognition.{
    Adversarial,
    BayesianNetwork,
    CostLaw,
    Interview,
    Pareto,
    Planner,
    Prolog,
    Temporal
  }

  @doc "Executes a cognition operation over the given subject."
  def execute(action, subject, opts \\ [])

  def execute(:bayesian_infer, %BayesianNetwork{} = bn, opts) do
    query_var = Keyword.fetch!(opts, :query)
    evidence = Keyword.get(opts, :evidence, %{})

    case BayesianNetwork.infer(bn, query_var, evidence) do
      {:ok, distribution} ->
        {:ok,
         %Result{
           engine: :beam,
           operation: :cognition,
           algorithm: :bayesian_exact_inference,
           subject_hash: Ex4pm.Core.Hash.digest(bn),
           standing: :alive,
           value: distribution,
           evidence: %{deterministic: true, query: query_var, evidence_count: map_size(evidence)}
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(:prolog_query, %Prolog{} = kb, opts) do
    query_goals = Keyword.fetch!(opts, :query)

    solutions = Prolog.query(kb, query_goals)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :prolog_horn_resolution,
       subject_hash: Ex4pm.Core.Hash.digest(kb),
       standing: :alive,
       value: %{solutions: solutions, solution_count: length(solutions)},
       evidence: %{deterministic: true, depth_bounded: true}
     }}
  end

  def execute(:plan, %Planner{} = planner, opts) do
    init_state = Keyword.fetch!(opts, :initial_state)
    goal_state = Keyword.fetch!(opts, :goal_state)

    case Planner.plan(planner, init_state, goal_state, opts) do
      {:ok, plan_res} ->
        {:ok,
         %Result{
           engine: :beam,
           operation: :cognition,
           algorithm: :strips_means_ends,
           subject_hash: Ex4pm.Core.Hash.digest(planner),
           standing: :alive,
           value: plan_res,
           evidence: %{sound: true, deterministic: true}
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(:temporal_relate, {interval_a, interval_b}, _opts) do
    relation = Temporal.relate(interval_a, interval_b)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :allen_13_relations,
       subject_hash: Ex4pm.Core.Hash.digest(%{a: interval_a, b: interval_b}),
       standing: :alive,
       value: %{relation: relation, interval_a: interval_a, interval_b: interval_b},
       evidence: %{deterministic: true}
     }}
  end

  def execute(:ltl_check, trace, opts) when is_list(trace) do
    formula = Keyword.fetch!(opts, :formula)
    satisfied? = Temporal.check_ltl(trace, formula)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :ltl_model_checker,
       subject_hash: Ex4pm.Core.Hash.digest(%{trace: trace, formula: inspect(formula)}),
       standing: :alive,
       value: %{satisfied?: satisfied?, trace_length: length(trace), formula: inspect(formula)},
       evidence: %{deterministic: true}
     }}
  end

  def execute(:pareto_rank, candidates, opts) when is_list(candidates) do
    objectives = Keyword.get(opts, :objectives, [{:fitness, :maximize}, {:cost, :minimize}])
    frontier_res = Pareto.compute_frontier(candidates, objectives)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :pareto_non_dominated_sort,
       subject_hash: Ex4pm.Core.Hash.digest(candidates),
       standing: :alive,
       value: frontier_res,
       evidence: %{deterministic: true, candidates_count: length(candidates)}
     }}
  end

  def execute(:cost_evaluate, trace_meta, opts) when is_map(trace_meta) do
    cost_res = CostLaw.evaluate_trace(trace_meta, opts)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :autosystems_cost_law,
       subject_hash: Ex4pm.Core.Hash.digest(trace_meta),
       standing: :alive,
       value: cost_res,
       evidence: %{deterministic: true}
     }}
  end

  def execute(:adversarial_audit, log, opts) do
    audit_res = Adversarial.audit_log(log, opts)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :autosystems_8_detectors,
       subject_hash: log.subject.hash,
       standing: if(audit_res.passed?, do: :alive, else: :blocked),
       value: audit_res,
       evidence: %{detector_count: 8, passed: audit_res.passed?}
     }}
  end

  def execute(:interview_evaluate, {question, chosen_option}, _opts) do
    case Interview.evaluate_response(question, chosen_option) do
      {:ok, res} ->
        {:ok,
         %Result{
           engine: :beam,
           operation: :cognition,
           algorithm: :interview_assist_scorer,
           subject_hash: Ex4pm.Core.Hash.digest(%{q: question.id, a: chosen_option}),
           standing: :alive,
           value: res,
           evidence: %{deterministic: true}
         }}

      {:error, err} ->
        {:error, err}
    end
  end
end
