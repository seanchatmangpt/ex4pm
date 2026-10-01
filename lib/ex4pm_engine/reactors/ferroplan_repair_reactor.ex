defmodule Ex4pmEngine.Reactors.FerroplanRepairReactor.Project do
  @moduledoc """
  Pure, deterministic projection of a compiled process plan to classical PDDL.

  Projection (documented contract):

    * every activity becomes a PDDL object `act<i>` (index in sorted activity
      order, so PDDL-illegal characters in activity labels never matter);
    * the single fluent `(at ?x)` holds the activity most recently completed;
      `(edge ?x ?y)` facts are the model edges (the compiled plan);
    * one action `step ?f ?t` requires `(at ?f)` and `(edge ?f ?t)` and moves
      `at` from `?f` to `?t`;
    * problem init is `(at <resume>)` where `resume` is the last activity of the
      longest model-conformant prefix of the deviating trace; the goal is
      `(at <goal>)` where `goal` is the model's final activity.

  The repair therefore resumes from the last conformant state, discarding the
  deviating event and everything after it, and plans a model-lawful
  continuation.
  """

  @domain """
  (define (domain process_repair)
    (:requirements :strips)
    (:predicates (at ?x) (edge ?x ?y))
    (:action step
      :parameters (?f ?t)
      :precondition (and (at ?f) (edge ?f ?t))
      :effect (and (at ?t) (not (at ?f)))))
  """

  @spec build([map()], String.t(), String.t()) :: %{
          domain: String.t(),
          problem: String.t(),
          names: %{String.t() => String.t()}
        }
  def build(model_edges, resume, goal) do
    activities =
      model_edges
      |> Enum.flat_map(&[&1.from, &1.to])
      |> Enum.concat([resume, goal])
      |> Enum.uniq()
      |> Enum.sort()

    ids = activities |> Enum.with_index() |> Map.new(fn {a, i} -> {a, "act#{i}"} end)
    # ferroplan reports upper-cased symbols; map those back to activity labels.
    names = Map.new(ids, fn {a, id} -> {String.upcase(id), a} end)

    edges =
      model_edges
      |> Enum.uniq()
      |> Enum.sort_by(&{&1.from, &1.to})
      |> Enum.map_join(" ", fn e -> "(edge #{ids[e.from]} #{ids[e.to]})" end)

    problem = """
    (define (problem repair)
      (:domain process_repair)
      (:objects #{Enum.map_join(activities, " ", &ids[&1])})
      (:init (at #{ids[resume]}) #{edges})
      (:goal (at #{ids[goal]})))
    """

    %{domain: @domain, problem: problem, names: names}
  end
end

defmodule Ex4pmEngine.Reactors.FerroplanRepairReactor do
  @moduledoc """
  Conformance deviation -> ferroplan replan -> wasm validation -> *proposed*
  repair. It NEVER actuates: the output is a plain intervention map with
  `standing: :partial_alive` and `actuation: :requires_brce`; applying it is
  only lawful through `Ex4pm.Evidence.BRCE` with explicit authority.

  ## Inputs (all required keys; pass `nil` for unused ones)

    * `:model_edges` -- the compiled plan: `[%{from: a, to: b}]` activity edges
    * `:traces` -- observed traces (`[[activity]]`) used to locate a deviation
      when `:deviation` is `nil`; conformance is measured by
      `Ex4pm.Engine.execute(:conform, ..., engine: :wasm_conform)`
    * `:deviation` -- explicit deviation `%{trace: [activity]}` (fallback; takes
      precedence over `:traces`)
    * `:goal` -- goal activity (default: the lexicographically first sink of the
      model edges)
    * `:engine_opts` -- extra opts for the engine calls (e.g. a ferroplan
      artifact pin); `nil` for none

  ## Steps

  `locate_deviation` -> `build_pddl` (`Project`, pure) -> `replan`
  (`Ex4pm.Engine.Ferroplan.plan/4`) -> `validate` (wasm `:conform` on the
  repaired trace must reach fitness 1.0, else the proposal is `:refused`) ->
  `propose`.

  Output (`:propose`): `%{status: :proposed | :refused | :no_deviation |
  :blocked, ...}`. A proposal carries `repaired_trace`, `plan_steps`,
  `validation` (fitness + wasm digests) and the intervention map under
  `:intervention`. Failures are data (`status`), never step errors, so a
  divergence handler cannot abort on a planner outage.
  """
  use Reactor

  alias Ex4pm.Engine.Ferroplan
  alias Ex4pmEngine.Reactors.FerroplanRepairReactor.Project

  input(:model_edges)
  input(:traces)
  input(:deviation)
  input(:goal)
  input(:engine_opts)

  step :locate_deviation do
    argument(:model_edges, input(:model_edges))
    argument(:traces, input(:traces))
    argument(:deviation, input(:deviation))
    argument(:goal, input(:goal))
    argument(:engine_opts, input(:engine_opts))
    max_retries(0)

    run(fn args, _ctx ->
      {:ok, Ex4pmEngine.Reactors.FerroplanRepairReactor.locate(args)}
    end)
  end

  step :build_pddl do
    argument(:located, result(:locate_deviation))
    max_retries(0)

    run(fn %{located: located}, _ctx ->
      case located do
        %{status: :deviating} ->
          pddl = Project.build(located.model_edges, located.resume, located.goal)
          {:ok, Map.put(located, :pddl, pddl)}

        other ->
          {:ok, other}
      end
    end)
  end

  step :replan do
    argument(:built, result(:build_pddl))
    argument(:engine_opts, input(:engine_opts))
    async?(false)
    max_retries(0)

    run(fn %{built: built, engine_opts: engine_opts}, _ctx ->
      {:ok, Ex4pmEngine.Reactors.FerroplanRepairReactor.replan(built, engine_opts || [])}
    end)
  end

  step :validate do
    argument(:planned, result(:replan))
    argument(:engine_opts, input(:engine_opts))
    async?(false)
    max_retries(0)

    run(fn %{planned: planned, engine_opts: engine_opts}, _ctx ->
      {:ok, Ex4pmEngine.Reactors.FerroplanRepairReactor.validate(planned, engine_opts || [])}
    end)
  end

  step :propose do
    argument(:validated, result(:validate))
    max_retries(0)

    run(fn %{validated: validated}, _ctx ->
      {:ok, Ex4pmEngine.Reactors.FerroplanRepairReactor.propose(validated)}
    end)
  end

  return(:propose)

  # -- step bodies (public so the DSL closures can call them) --------------

  @doc false
  def locate(%{model_edges: edges} = args) do
    engine_opts = Map.get(args, :engine_opts) || []
    goal = Map.get(args, :goal) || default_goal(edges)

    trace_result =
      case Map.get(args, :deviation) do
        %{} = dev ->
          {:ok, fetch(dev, :trace), nil}

        nil ->
          traces = Map.get(args, :traces) || []
          conformance = conformance(traces, edges, engine_opts)
          {:ok, Enum.find(traces, &(not conformant?(&1, edges))), conformance}
      end

    with {:ok, trace, conformance} when is_list(trace) <- trace_result do
      prefix = conformant_prefix(trace, edges)

      if prefix == trace or prefix == [] do
        %{status: :no_deviation, reason: :no_deviating_trace, conformance: conformance}
      else
        %{
          status: :deviating,
          model_edges: edges,
          trace: trace,
          prefix: prefix,
          resume: List.last(prefix),
          goal: goal,
          conformance: conformance
        }
      end
    else
      _ -> %{status: :no_deviation, reason: :no_deviating_trace, conformance: nil}
    end
  end

  @doc false
  def replan(%{status: :deviating, pddl: pddl} = built, engine_opts) do
    case Ferroplan.plan(pddl.domain, pddl.problem, %{}, engine_opts) do
      {:ok, %{"solved" => true, "plan" => %{"steps" => steps}} = response} ->
        activities =
          Enum.map(steps, fn %{"args" => [_from, to]} -> Map.fetch!(pddl.names, to) end)

        built
        |> Map.put(:status, :planned)
        |> Map.put(:plan_steps, activities)
        |> Map.put(:ferroplan, Map.take(response, ["mode", "statistics"]))

      {:ok, response} ->
        Map.merge(built, %{status: :blocked, reason: :no_repair_plan, ferroplan: response})

      {:error, reason} ->
        Map.merge(built, %{status: :blocked, reason: reason})
    end
  end

  def replan(other, _engine_opts), do: other

  @doc false
  def validate(%{status: :planned} = planned, engine_opts) do
    repaired = planned.prefix ++ planned.plan_steps
    opts = Keyword.put(engine_opts, :engine, :wasm_conform)
    subject = %{traces: [repaired], model_edges: planned.model_edges}

    case Ex4pm.Engine.execute(:conform, subject, opts) do
      {:ok, %Ex4pm.Engine.Result{value: %{"fitness" => fitness}} = result} ->
        validation = %{
          fitness: fitness,
          engine: result.engine,
          standing: result.standing,
          request_digest: Map.get(result.evidence, :request_digest),
          result_digest: Map.get(result.evidence, :result_digest),
          replay_verified: Map.get(result.evidence, :replay_verified)
        }

        if fitness == 1.0 do
          Map.merge(planned, %{
            status: :validated,
            repaired_trace: repaired,
            validation: validation
          })
        else
          Map.merge(planned, %{
            status: :refused,
            broken_term: :repaired_trace_still_diverges,
            repaired_trace: repaired,
            validation: validation
          })
        end

      {:ok, %Ex4pm.Engine.Result{value: value}} ->
        Map.merge(planned, %{status: :blocked, reason: {:validation_error, value}})

      {:error, reason} ->
        Map.merge(planned, %{status: :blocked, reason: {:validation_unavailable, reason}})
    end
  end

  def validate(other, _engine_opts), do: other

  @doc false
  def propose(%{status: :validated} = v) do
    %{
      status: :proposed,
      repaired_trace: v.repaired_trace,
      plan_steps: v.plan_steps,
      validation: v.validation,
      deviation: %{trace: v.trace, conformant_prefix: v.prefix, resume_from: v.resume},
      intervention: %{
        kind: :process_repair,
        state: :proposed,
        standing: :partial_alive,
        actuation: :requires_brce,
        authority_domain: :construct,
        actuation_performed: false,
        proposed_trace: v.repaired_trace,
        plan_steps: v.plan_steps,
        resume_from: v.resume,
        goal: v.goal,
        validated_by: %{engine: :wasm_conform, fitness: v.validation.fitness},
        planner: %{
          engine: :ferroplan,
          op: :plan,
          statistics: get_in(v, [:ferroplan, "statistics"])
        }
      }
    }
  end

  def propose(%{status: :refused} = v) do
    %{
      status: :refused,
      broken_term: v.broken_term,
      repaired_trace: v.repaired_trace,
      validation: v.validation,
      actuation: :requires_brce,
      intervention: nil
    }
  end

  def propose(%{status: :no_deviation} = v), do: Map.put(v, :intervention, nil)

  def propose(%{status: :blocked} = v),
    do: %{status: :blocked, reason: v.reason, standing: :blocked, intervention: nil}

  # -- helpers ----------------------------------------------------------------

  defp conformance(traces, edges, engine_opts) do
    opts = Keyword.put(engine_opts, :engine, :wasm_conform)

    case Ex4pm.Engine.execute(:conform, %{traces: traces, model_edges: edges}, opts) do
      {:ok, %Ex4pm.Engine.Result{} = r} -> %{standing: r.standing, result: r.value}
      {:error, reason} -> %{standing: :blocked, reason: reason}
    end
  end

  defp default_goal(edges) do
    froms = MapSet.new(edges, & &1.from)

    edges
    |> Enum.map(& &1.to)
    |> Enum.reject(&MapSet.member?(froms, &1))
    |> Enum.sort()
    |> List.first()
  end

  defp edge_set(edges), do: MapSet.new(edges, &{&1.from, &1.to})

  defp conformant?(trace, edges), do: conformant_prefix(trace, edges) == trace

  defp conformant_prefix([], _edges), do: []

  defp conformant_prefix([first | rest], edges) do
    set = edge_set(edges)

    {prefix, _} =
      Enum.reduce_while(rest, {[first], first}, fn next, {acc, prev} ->
        if MapSet.member?(set, {prev, next}),
          do: {:cont, {[next | acc], next}},
          else: {:halt, {acc, prev}}
      end)

    Enum.reverse(prefix)
  end

  defp fetch(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
end
