defmodule Ex4pmEvidence.Conformance.Violation do
  @moduledoc "A structured violation record detected during conformance evaluation."
  @enforce_keys [:dimension, :rule, :message]
  defstruct [
    :dimension,
    :rule,
    :message,
    case_id: nil,
    object_id: nil,
    events: [],
    details: %{}
  ]

  @type dimension :: :fitness | :precision | :policy | :lifecycle | :causal
  @type t :: %__MODULE__{
          dimension: dimension(),
          rule: atom() | String.t(),
          message: String.t(),
          case_id: String.t() | nil,
          object_id: String.t() | nil,
          events: [String.t()],
          details: map()
        }
end

defmodule Ex4pmEvidence.Conformance.Vector do
  @moduledoc "Multi-dimensional conformance vector containing 5 orthogonal evaluation axes."
  @enforce_keys [
    :fitness,
    :precision,
    :policy_conformance,
    :lifecycle_conformance,
    :causal_conformance,
    :overall_score
  ]
  defstruct [
    :fitness,
    :precision,
    :policy_conformance,
    :lifecycle_conformance,
    :causal_conformance,
    :overall_score,
    details: %{},
    violations: [],
    standing: :alive,
    subject_hash: nil
  ]

  @type t :: %__MODULE__{
          fitness: float(),
          precision: float(),
          policy_conformance: float(),
          lifecycle_conformance: float(),
          causal_conformance: float(),
          overall_score: float(),
          details: map(),
          violations: [Ex4pmEvidence.Conformance.Violation.t()],
          standing: Ex4pm.Standing.t(),
          subject_hash: String.t() | nil
        }
end

defmodule Ex4pmEvidence.Conformance do
  @moduledoc """
  Multi-dimensional Conformance Checker calculating:
  1. Fitness (token replay & trace alignment)
  2. Precision (anti-alignment & escaping edges)
  3. Policy Conformance (Separation/Binding of Duties, SLA, Mandatory/Forbidden rules)
  4. Lifecycle Conformance (Transactional lifecycle state machine transitions)
  5. Causal Conformance (Partial order and object-centric causal dependencies)
  """

  alias Ex4pm.Core.Hash
  alias Ex4pm.EventLog
  alias Ex4pm.OCEL
  alias Ex4pm.Refusal
  alias Ex4pmCore.ProcessIR
  alias Ex4pmEvidence.Conformance.{Vector, Violation}

  @doc """
  Evaluates multi-dimensional conformance of an EventLog against a process model or ProcessIR.
  """
  def evaluate(event_log, model_or_ir, opts \\ [])

  def evaluate(raw_log, model_or_ir, opts)
      when is_map(raw_log) and not is_struct(raw_log, EventLog) do
    with {:ok, log} <- OCEL.normalize(raw_log) do
      evaluate(log, model_or_ir, opts)
    end
  end

  def evaluate(%EventLog{} = log, model_or_ir, opts) do
    object_type = Keyword.get(opts, :object_type)

    with {:ok, traces} <- extract_traces(log, object_type) do
      # 1. Calculate Fitness
      {fitness_score, fitness_details, fitness_violations} =
        calculate_fitness(traces, model_or_ir, opts)

      # 2. Calculate Precision
      {precision_score, precision_details, precision_violations} =
        calculate_precision(traces, model_or_ir, opts)

      # 3. Calculate Policy Conformance
      {policy_score, policy_details, policy_violations} =
        calculate_policy_conformance(log, traces, model_or_ir, opts)

      # 4. Calculate Lifecycle Conformance
      {lifecycle_score, lifecycle_details, lifecycle_violations} =
        calculate_lifecycle_conformance(log, traces, model_or_ir, opts)

      # 5. Calculate Causal Conformance
      {causal_score, causal_details, causal_violations} =
        calculate_causal_conformance(log, traces, model_or_ir, opts)

      # Overall harmonic or weighted mean score
      scores = [fitness_score, precision_score, policy_score, lifecycle_score, causal_score]
      overall = Enum.sum(scores) / length(scores)

      all_violations =
        fitness_violations ++
          precision_violations ++
          policy_violations ++
          lifecycle_violations ++
          causal_violations

      details = %{
        fitness: fitness_details,
        precision: precision_details,
        policy_conformance: policy_details,
        lifecycle_conformance: lifecycle_details,
        causal_conformance: causal_details,
        trace_count: map_size(traces),
        event_count: length(log.events)
      }

      subject_payload = %{
        log_hash: log.subject.hash,
        model_hash: model_hash(model_or_ir),
        scores: scores
      }

      vector = %Vector{
        fitness: Float.round(fitness_score, 4),
        precision: Float.round(precision_score, 4),
        policy_conformance: Float.round(policy_score, 4),
        lifecycle_conformance: Float.round(lifecycle_score, 4),
        causal_conformance: Float.round(causal_score, 4),
        overall_score: Float.round(overall, 4),
        details: details,
        violations: all_violations,
        standing: :alive,
        subject_hash: Hash.digest(subject_payload)
      }

      {:ok, vector}
    end
  end

  def evaluate(other_log, _model, _opts) do
    {:error,
     Refusal.new(
       :invalid_conformance_log,
       "Conformance evaluation requires a valid EventLog or map",
       subject: other_log
     )}
  end

  # --- 1. Fitness Calculation ---

  defp calculate_fitness(traces, model, _opts) do
    allowed_edges = extract_model_edges(model)
    allowed_starts = extract_model_starts(model)
    allowed_ends = extract_model_ends(model)

    trace_results =
      Enum.map(traces, fn {case_id, events} ->
        acts = Enum.map(events, & &1.activity)

        case acts do
          [] ->
            {1.0, []}

          [single] ->
            v = []

            v =
              if allowed_starts != nil and not MapSet.member?(allowed_starts, single),
                do: [single | v],
                else: v

            v =
              if allowed_ends != nil and not MapSet.member?(allowed_ends, single),
                do: [single | v],
                else: v

            score = if v == [], do: 1.0, else: 0.5

            {score,
             Enum.map(v, fn a ->
               %Violation{
                 dimension: :fitness,
                 rule: :invalid_trace_endpoint,
                 case_id: to_string(case_id),
                 message: "Activity #{a} is not an allowed start/end activity"
               }
             end)}

          _ ->
            # Check edge transitions
            edges = Enum.chunk_every(acts, 2, 1, :discard) |> Enum.map(fn [a, b] -> {a, b} end)
            total_edges = length(edges)

            deviations =
              if allowed_edges != nil do
                Enum.filter(edges, fn edge -> not MapSet.member?(allowed_edges, edge) end)
              else
                []
              end

            score =
              if total_edges == 0, do: 1.0, else: max(0.0, 1.0 - length(deviations) / total_edges)

            violations =
              Enum.map(deviations, fn {from_a, to_a} ->
                %Violation{
                  dimension: :fitness,
                  rule: :unfitted_transition,
                  case_id: to_string(case_id),
                  message: "Transition #{from_a} -> #{to_a} is not admitted by model",
                  details: %{from: from_a, to: to_a}
                }
              end)

            {score, violations}
        end
      end)

    scores = Enum.map(trace_results, &elem(&1, 0))
    violations = Enum.flat_map(trace_results, &elem(&1, 1))
    avg_fitness = if scores == [], do: 1.0, else: Enum.sum(scores) / length(scores)

    {
      avg_fitness,
      %{trace_fitness_distribution: scores, total_deviations: length(violations)},
      violations
    }
  end

  # --- 2. Precision Calculation ---

  defp calculate_precision(traces, model, _opts) do
    model_edges = extract_model_edges(model)

    if is_nil(model_edges) or MapSet.size(model_edges) == 0 do
      {1.0, %{reason: :no_edge_restrictions}, []}
    else
      # Group model edges by source activity to see enabled transitions from each state
      model_successors =
        model_edges
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Map.new(fn {src, tgts} -> {src, MapSet.new(tgts)} end)

      # For each prefix activity in traces, find what was observed vs what model allowed
      observed_transitions_by_state =
        traces
        |> Map.values()
        |> Enum.flat_map(fn events ->
          events
          |> Enum.map(& &1.activity)
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [a, b] -> {a, b} end)
        end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Map.new(fn {src, tgts} -> {src, MapSet.new(tgts)} end)

      # For each visited state (source activity), precision is |observed successors| / |model successors|
      precisions =
        Enum.map(observed_transitions_by_state, fn {src, observed_tgts} ->
          model_tgts = Map.get(model_successors, src, observed_tgts)
          # Intersection of observed with model allowed
          valid_observed = MapSet.intersection(observed_tgts, model_tgts)
          attainable = MapSet.size(model_tgts)

          if attainable == 0 do
            1.0
          else
            min(1.0, MapSet.size(valid_observed) / attainable)
          end
        end)

      avg_precision =
        if precisions == [], do: 1.0, else: Enum.sum(precisions) / length(precisions)

      {
        avg_precision,
        %{state_precisions: precisions, evaluated_states_count: length(precisions)},
        []
      }
    end
  end

  # --- 3. Policy Conformance Calculation ---

  defp calculate_policy_conformance(log, traces, model, opts) do
    policies = extract_policies(model, opts)

    if policies == [] do
      {1.0, %{policies_evaluated: 0}, []}
    else
      results =
        Enum.flat_map(policies, fn policy ->
          evaluate_single_policy(policy, log, traces)
        end)

      total_checks = length(results)
      violations = Enum.filter(results, &(&1 != :ok))

      score =
        if total_checks == 0,
          do: 1.0,
          else: max(0.0, (total_checks - length(violations)) / total_checks)

      {
        score,
        %{total_policy_checks: total_checks, violation_count: length(violations)},
        violations
      }
    end
  end

  defp evaluate_single_policy(policy, _log, traces) do
    p_type = Map.get(policy, :type) || Map.get(policy, "type")
    targets = Map.get(policy, :target_activities) || Map.get(policy, "target_activities") || []
    rules = Map.get(policy, :rules) || Map.get(policy, "rules") || %{}
    p_id = Map.get(policy, :id) || Map.get(policy, "id") || "policy"

    case p_type do
      :sod ->
        # Separation of Duties: target activities must not share the same performer / resource
        Enum.map(traces, fn {case_id, events} ->
          relevant_events = Enum.filter(events, &(&1.activity in targets))
          performers = Enum.map(relevant_events, &extract_performer/1) |> Enum.reject(&is_nil/1)

          if length(performers) > 1 and length(Enum.uniq(performers)) < length(performers) do
            %Violation{
              dimension: :policy,
              rule: :sod_violation,
              case_id: to_string(case_id),
              events: Enum.map(relevant_events, & &1.id),
              message:
                "Policy #{p_id} (SoD) violated: activities #{inspect(targets)} executed by same resource #{inspect(hd(performers))}",
              details: %{policy_id: p_id, performers: performers}
            }
          else
            :ok
          end
        end)

      :bod ->
        # Binding of Duties: target activities must be executed by the SAME performer
        Enum.map(traces, fn {case_id, events} ->
          relevant_events = Enum.filter(events, &(&1.activity in targets))
          performers = Enum.map(relevant_events, &extract_performer/1) |> Enum.reject(&is_nil/1)

          if length(performers) >= length(targets) and length(Enum.uniq(performers)) > 1 do
            %Violation{
              dimension: :policy,
              rule: :bod_violation,
              case_id: to_string(case_id),
              events: Enum.map(relevant_events, & &1.id),
              message:
                "Policy #{p_id} (BoD) violated: activities #{inspect(targets)} executed by different resources #{inspect(performers)}",
              details: %{policy_id: p_id, performers: performers}
            }
          else
            :ok
          end
        end)

      :sla ->
        # SLA: duration between first and last target activity must be <= max_duration_ms
        max_duration_ms =
          cond do
            is_number(Map.get(rules, :max_duration_ms)) ->
              Map.get(rules, :max_duration_ms)

            is_number(Map.get(rules, "max_duration_ms")) ->
              Map.get(rules, "max_duration_ms")

            is_number(Map.get(rules, :max_duration_hours)) ->
              Map.get(rules, :max_duration_hours) * 3_600_000

            is_number(Map.get(rules, "max_duration_hours")) ->
              Map.get(rules, "max_duration_hours") * 3_600_000

            is_number(Map.get(rules, :max_duration_minutes)) ->
              Map.get(rules, :max_duration_minutes) * 60_000

            is_number(Map.get(rules, "max_duration_minutes")) ->
              Map.get(rules, "max_duration_minutes") * 60_000

            true ->
              nil
          end

        if max_duration_ms > 0 do
          Enum.map(traces, fn {case_id, events} ->
            matched = Enum.filter(events, &(&1.activity in targets))

            if length(matched) >= 2 do
              first = hd(matched)
              last = List.last(matched)
              diff = duration_between(first.timestamp, last.timestamp)

              if diff && diff > max_duration_ms do
                %Violation{
                  dimension: :policy,
                  rule: :sla_violation,
                  case_id: to_string(case_id),
                  events: [first.id, last.id],
                  message:
                    "Policy #{p_id} (SLA) violated: elapsed time #{diff}ms exceeds threshold #{max_duration_ms}ms",
                  details: %{policy_id: p_id, elapsed_ms: diff, max_ms: max_duration_ms}
                }
              else
                :ok
              end
            else
              :ok
            end
          end)
        else
          [:ok]
        end

      :mandatory ->
        # If any of targets occur, all must occur
        Enum.map(traces, fn {case_id, events} ->
          acts = Enum.map(events, & &1.activity) |> MapSet.new()
          present = Enum.filter(targets, &MapSet.member?(acts, &1))
          missing = Enum.reject(targets, &MapSet.member?(acts, &1))

          if present != [] and missing != [] do
            %Violation{
              dimension: :policy,
              rule: :mandatory_activity_missing,
              case_id: to_string(case_id),
              message:
                "Policy #{p_id} violated: present #{inspect(present)} but missing required #{inspect(missing)}",
              details: %{policy_id: p_id, missing: missing}
            }
          else
            :ok
          end
        end)

      :forbidden ->
        # Forbidden sequence: targets in forbidden order
        forbidden_pair =
          case targets do
            [a, b | _] -> {a, b}
            _ -> nil
          end

        if forbidden_pair do
          {f_a, f_b} = forbidden_pair

          Enum.map(traces, fn {case_id, events} ->
            acts = Enum.map(events, & &1.activity)

            has_forbidden =
              acts
              |> Enum.chunk_every(2, 1, :discard)
              |> Enum.any?(fn [a, b] -> a == f_a and b == f_b end)

            if has_forbidden do
              %Violation{
                dimension: :policy,
                rule: :forbidden_transition_occurred,
                case_id: to_string(case_id),
                message: "Policy #{p_id} violated: forbidden sequence #{f_a} -> #{f_b} occurred",
                details: %{policy_id: p_id, forbidden: forbidden_pair}
              }
            else
              :ok
            end
          end)
        else
          [:ok]
        end

      _ ->
        [:ok]
    end
  end

  # --- 4. Lifecycle Conformance Calculation ---

  defp calculate_lifecycle_conformance(_log, traces, _model, _opts) do
    # Standard lifecycle transitions:
    # create / schedule -> start -> complete / abort / cancel
    valid_transitions =
      MapSet.new([
        {"create", "start"},
        {"schedule", "start"},
        {"start", "complete"},
        {"start", "suspend"},
        {"suspend", "resume"},
        {"resume", "complete"},
        {"start", "abort"},
        {"start", "cancel"},
        {"create", "cancel"}
      ])

    results =
      Enum.flat_map(traces, fn {case_id, events} ->
        # Group events by activity name to check per-activity lifecycle state machine
        Enum.group_by(events, & &1.activity)
        |> Enum.flat_map(fn {act_name, act_events} ->
          states =
            Enum.map(act_events, fn ev ->
              extract_lifecycle_state(ev)
            end)
            |> Enum.reject(&is_nil/1)

          case states do
            [] ->
              [:ok]

            [_single] ->
              [:ok]

            transitions ->
              transitions
              |> Enum.chunk_every(2, 1, :discard)
              |> Enum.map(fn [s1, s2] ->
                if MapSet.member?(valid_transitions, {s1, s2}) or s1 == s2 do
                  :ok
                else
                  %Violation{
                    dimension: :lifecycle,
                    rule: :invalid_lifecycle_transition,
                    case_id: to_string(case_id),
                    message:
                      "Activity '#{act_name}' executed invalid lifecycle step #{s1} -> #{s2}",
                    details: %{activity: act_name, from_state: s1, to_state: s2}
                  }
                end
              end)
          end
        end)
      end)

    total_checks = length(results)
    violations = Enum.filter(results, &(&1 != :ok))

    score =
      if total_checks == 0,
        do: 1.0,
        else: max(0.0, (total_checks - length(violations)) / total_checks)

    {
      score,
      %{total_lifecycle_checks: total_checks, violations_count: length(violations)},
      violations
    }
  end

  # --- 5. Causal Conformance Calculation ---

  defp calculate_causal_conformance(_log, traces, model, opts) do
    causal_edges = extract_causal_dependencies(model, opts)

    if causal_edges == [] do
      {1.0, %{causal_rules_evaluated: 0}, []}
    else
      results =
        Enum.flat_map(traces, fn {case_id, events} ->
          act_indexes =
            events
            |> Enum.with_index()
            |> Enum.map(fn {ev, idx} -> {ev.activity, {idx, ev.timestamp}} end)
            |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

          Enum.map(causal_edges, fn {cause_act, effect_act} ->
            cause_occurrences = Map.get(act_indexes, cause_act, [])
            effect_occurrences = Map.get(act_indexes, effect_act, [])

            if cause_occurrences != [] and effect_occurrences != [] do
              # Cause must occur at least once before effect
              first_cause_idx = hd(cause_occurrences) |> elem(0)
              first_effect_idx = hd(effect_occurrences) |> elem(0)

              if first_cause_idx > first_effect_idx do
                %Violation{
                  dimension: :causal,
                  rule: :causal_inversion,
                  case_id: to_string(case_id),
                  message:
                    "Causal order inverted: #{cause_act} must precede #{effect_act}, but #{effect_act} appeared first",
                  details: %{
                    cause: cause_act,
                    effect: effect_act,
                    cause_idx: first_cause_idx,
                    effect_idx: first_effect_idx
                  }
                }
              else
                :ok
              end
            else
              :ok
            end
          end)
        end)

      total_checks = length(results)
      violations = Enum.filter(results, &(&1 != :ok))

      score =
        if total_checks == 0,
          do: 1.0,
          else: max(0.0, (total_checks - length(violations)) / total_checks)

      {
        score,
        %{total_causal_checks: total_checks, violations_count: length(violations)},
        violations
      }
    end
  end

  # --- Extraction helpers ---

  defp extract_traces(%EventLog{} = log, object_type) do
    OCEL.flatten(log, object_type)
  end

  defp extract_model_edges(%ProcessIR{partial_orders: pos}) do
    edges =
      pos
      |> Map.values()
      |> Enum.flat_map(& &1.edges)
      |> MapSet.new()

    if MapSet.size(edges) == 0, do: nil, else: edges
  end

  defp extract_model_edges(%{type: :dfg, edges: edges}) when is_map(edges) do
    Map.keys(edges) |> MapSet.new()
  end

  defp extract_model_edges(%{edges: edges}) when is_map(edges) do
    Map.keys(edges) |> MapSet.new()
  end

  defp extract_model_edges(%{edges: edges}) when is_list(edges) do
    edges
    |> Enum.map(fn
      {a, b} -> {to_string(a), to_string(b)}
      [a, b] -> {to_string(a), to_string(b)}
      %{source: a, target: b} -> {to_string(a), to_string(b)}
    end)
    |> MapSet.new()
  end

  defp extract_model_edges(_), do: nil

  defp extract_model_starts(%{starts: starts}) when is_map(starts),
    do: Map.keys(starts) |> MapSet.new()

  defp extract_model_starts(_), do: nil

  defp extract_model_ends(%{ends: ends}) when is_map(ends), do: Map.keys(ends) |> MapSet.new()
  defp extract_model_ends(_), do: nil

  defp extract_policies(%ProcessIR{policies: policies}, opts) do
    explicit = Keyword.get(opts, :policies, [])
    (Map.values(policies) ++ explicit) |> Enum.map(&normalize_policy_map/1)
  end

  defp extract_policies(_model, opts) do
    Keyword.get(opts, :policies, []) |> Enum.map(&normalize_policy_map/1)
  end

  defp normalize_policy_map(%ProcessIR.Policy{} = p), do: Map.from_struct(p)
  defp normalize_policy_map(map) when is_map(map), do: map

  defp extract_causal_dependencies(%ProcessIR{partial_orders: pos}, opts) do
    po_edges =
      pos
      |> Map.values()
      |> Enum.flat_map(& &1.edges)

    explicit = Keyword.get(opts, :causal_dependencies, [])

    (po_edges ++ explicit)
    |> Enum.map(fn {f, t} -> {to_string(f), to_string(t)} end)
    |> Enum.uniq()
  end

  defp extract_causal_dependencies(_model, opts) do
    Keyword.get(opts, :causal_dependencies, [])
    |> Enum.map(fn {f, t} -> {to_string(f), to_string(t)} end)
    |> Enum.uniq()
  end

  defp extract_performer(event) do
    attrs = event.attributes || %{}

    Map.get(attrs, "resource") ||
      Map.get(attrs, :resource) ||
      Map.get(attrs, "actor") ||
      Map.get(attrs, :actor) ||
      Map.get(attrs, "user") ||
      Map.get(attrs, :user) ||
      Map.get(attrs, "performer") ||
      Map.get(attrs, :performer) ||
      Map.get(attrs, "org:resource") ||
      Map.get(attrs, :"org:resource")
  end

  defp extract_lifecycle_state(event) do
    attrs = event.attributes || %{}

    state =
      Map.get(attrs, "lifecycle:transition") ||
        Map.get(attrs, :"lifecycle:transition") ||
        Map.get(attrs, "lifecycle") ||
        Map.get(attrs, :lifecycle) ||
        Map.get(attrs, "status") ||
        Map.get(attrs, :status)

    if state, do: to_string(state), else: nil
  end

  defp duration_between(t1, t2) do
    with {:ok, dt1, _} <- DateTime.from_iso8601(to_string(t1)),
         {:ok, dt2, _} <- DateTime.from_iso8601(to_string(t2)) do
      DateTime.diff(dt2, dt1, :millisecond)
    else
      _ -> nil
    end
  end

  defp model_hash(%ProcessIR{} = ir), do: ProcessIR.digest(ir)
  defp model_hash(model), do: Hash.digest(model)
end

defmodule Ex4pm.Evidence.Conformance do
  @moduledoc "Alias module for Ex4pmEvidence.Conformance."
  defdelegate evaluate(event_log, model_or_ir, opts \\ []), to: Ex4pmEvidence.Conformance
end
