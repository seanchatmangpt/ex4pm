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

  alias Ex4pmEngine.{
    Alignment,
    Choreography,
    DAPN,
    ETCPrecision,
    LTLf,
    POWL,
    SoundnessProver
  }

  alias Ex4pmEngine.Cognition.{
    Adversarial,
    BayesianNetwork,
    Causal,
    CostLaw,
    CriticalPath,
    Interview,
    Markov,
    Ocpq,
    Pareto,
    Planner,
    Prolog,
    Survival,
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

  def execute(:ocpq_query, {%Ex4pm.EventLog{} = log, %Ocpq.QueryTree{} = tree}, _opts) do
    query_res = Ocpq.evaluate_query(log, tree)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :ocpq_object_centric_query,
       subject_hash: log.subject.hash,
       standing: if(query_res.satisfied?, do: :alive, else: :blocked),
       value: query_res,
       evidence: %{deterministic: true, satisfied: query_res.satisfied?}
     }}
  end

  def execute(:survival_fit, durations_ms, _opts) when is_list(durations_ms) do
    model = Survival.fit_kaplan_meier(durations_ms)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :kaplan_meier_survival,
       subject_hash: Ex4pm.Core.Hash.digest(durations_ms),
       standing: :alive,
       value: model,
       evidence: %{deterministic: true, sample_size: model.sample_size}
     }}
  end

  def execute(:survival_predict, {model, elapsed_ms}, _opts) when is_map(model) do
    prediction = Survival.predict_remaining_time(model, elapsed_ms)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :remaining_useful_life,
       subject_hash: Ex4pm.Core.Hash.digest(%{m: model.median_duration_ms, e: elapsed_ms}),
       standing: :alive,
       value: prediction,
       evidence: %{deterministic: true}
     }}
  end

  def execute(:causal_discover, traces, _opts) do
    causal_res = Causal.infer_causal_dependencies(traces)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :causal_dependency_matrix,
       subject_hash: Ex4pm.Core.Hash.digest(traces),
       standing: :alive,
       value: causal_res,
       evidence: %{deterministic: true, edge_count: causal_res.edge_count}
     }}
  end

  def execute(:markov_fit, traces, _opts) do
    markov_res = Markov.fit_markov_chain(traces)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :markov_transition_probability,
       subject_hash: Ex4pm.Core.Hash.digest(traces),
       standing: :alive,
       value: markov_res,
       evidence: %{deterministic: true, state_count: markov_res.state_count}
     }}
  end

  def execute(:critical_path, tasks, _opts) when is_list(tasks) do
    cpm_res = CriticalPath.analyze_schedule(tasks)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :critical_path_method,
       subject_hash: Ex4pm.Core.Hash.digest(tasks),
       standing: :alive,
       value: cpm_res,
       evidence: %{deterministic: true, total_duration_ms: cpm_res.total_duration_ms}
     }}
  end

  def execute(:optimal_alignment, {trace, net_spec}, opts)
      when is_list(trace) and is_map(net_spec) do
    case Alignment.align_trace(trace, net_spec, opts) do
      {:ok, alignment} ->
        {:ok,
         %Result{
           engine: :beam,
           operation: :cognition,
           algorithm: :a_star_optimal_alignment,
           subject_hash: Ex4pm.Core.Hash.digest(%{trace: trace, net: net_spec}),
           standing: if(alignment.fitness >= 0.85, do: :alive, else: :blocked),
           value: alignment,
           evidence: %{
             deterministic: true,
             total_cost: alignment.total_cost,
             fitness: alignment.fitness,
             moves_count: length(alignment.moves)
           }
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(:prove_soundness, net_spec, _opts) when is_map(net_spec) do
    report = SoundnessProver.verify_soundness(net_spec)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :reachability_graph_1_safe_soundness,
       subject_hash: Ex4pm.Core.Hash.digest(net_spec),
       standing: if(report.sound?, do: :alive, else: :blocked),
       value: report,
       evidence: %{
         deterministic: true,
         sound: report.sound?,
         reachable_markings: report.reachable_markings_count,
         deadlocks_count: length(report.deadlocks)
       }
     }}
  end

  def execute(:powl_to_net, %POWL.Node{} = powl_tree, _opts) do
    net = POWL.to_workflow_net(powl_tree)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :powl_2_sound_by_construction_tree,
       subject_hash: Ex4pm.Core.Hash.digest(powl_tree),
       standing: :alive,
       value: net,
       evidence: %{
         deterministic: true,
         sound_by_construction: true,
         transitions_count: map_size(net.transitions)
       }
     }}
  end

  def execute(:etc_precision, {traces, net_spec}, _opts)
      when is_list(traces) and is_map(net_spec) do
    prec_report = ETCPrecision.calculate_precision(traces, net_spec)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :adriansyah_escaping_edge_etc_precision,
       subject_hash: Ex4pm.Core.Hash.digest(%{traces: traces, net: net_spec}),
       standing: if(prec_report.precision >= 0.70, do: :alive, else: :blocked),
       value: prec_report,
       evidence: %{deterministic: true, precision: prec_report.precision}
     }}
  end

  def execute(:dapn_execute, {trace, dapn_spec}, _opts)
      when is_list(trace) and is_map(dapn_spec) do
    case DAPN.execute_dapn_trace(trace, dapn_spec) do
      {:ok, result} ->
        {:ok,
         %Result{
           engine: :beam,
           operation: :cognition,
           algorithm: :data_aware_petri_net_guard_execution,
           subject_hash: Ex4pm.Core.Hash.digest(%{trace: trace, net: dapn_spec}),
           standing: :alive,
           value: result,
           evidence: %{deterministic: true, satisfied: true}
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(:ltlf_evaluate, {trace, formulas}, _opts) when is_list(trace) do
    report = LTLf.evaluate_trace(trace, formulas)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :ltlf_finite_trace_model_checking,
       subject_hash: Ex4pm.Core.Hash.digest(%{trace: trace, formulas: formulas}),
       standing: if(report.satisfied?, do: :alive, else: :blocked),
       value: report,
       evidence: %{
         deterministic: true,
         satisfied: report.satisfied?,
         violations_count: report.violations_count
       }
     }}
  end

  def execute(:choreography_verify, {agent_nets, channels}, _opts)
      when is_list(agent_nets) and is_list(channels) do
    choreo_report = Choreography.verify_choreography(agent_nets, channels)

    {:ok,
     %Result{
       engine: :beam,
       operation: :cognition,
       algorithm: :multi_agent_communicating_choreography,
       subject_hash: Ex4pm.Core.Hash.digest(%{agents: agent_nets, channels: channels}),
       standing: if(choreo_report.sound?, do: :alive, else: :blocked),
       value: choreo_report,
       evidence: %{
         deterministic: true,
         sound: choreo_report.sound?,
         orphan_messages: choreo_report.orphan_messages?,
         states_count: choreo_report.composite_reachable_states
       }
     }}
  end
end
