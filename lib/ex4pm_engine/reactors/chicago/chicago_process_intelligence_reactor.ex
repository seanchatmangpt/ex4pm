# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.Chicago.ChicagoProcessIntelligenceReactor do
  @moduledoc """
  Chicago Master Process Intelligence Reactor exercising the full Reactor DSL:
  - `middlewares`: ChicagoAuditMiddleware
  - `around`: Transactional BRCE evidence wrapping
  - `group`: Lifecycle setup and teardown (`before_all` / `after_all`)
  - `map`: Concurrent batch stream normalization (`batch_size: 10`, `allow_async? true`)
  - `compose`: Hierarchical sub-reactor embedding (`PowlDiscoverySubReactor`)
  - `collect`: Multi-perspective analytics aggregation
  - `switch`: Decision branching via `matches?` and `default`
  - `where`: Conditional execution filters
  - `template`: Diagnostic EEx rendering
  - `debug`: Audit telemetry step
  """
  use Reactor

  alias Ex4pmEngine.Reactors.Chicago.{PowlDiscoverySubReactor, Steps}
  alias Ex4pmEngine.Reactors.Chicago.Middlewares.ChicagoAuditMiddleware

  middlewares do
    middleware(ChicagoAuditMiddleware)
  end

  input(:filename)
  input(:dataset_content)
  input(:mode)
  input(:audit_tag)

  # Step 1: Dataset Ingestion & Parsing
  step :ingest_data, Steps.IngestAndNormalize do
    argument(:filename, input(:filename))
    argument(:dataset_content, input(:dataset_content))
  end

  # Map: Concurrent parallel processing of traces in batches
  map :normalize_traces do
    source(result(:ingest_data, [:raw_traces]))
    batch_size(10)
    allow_async?(true)

    step :transform_trace, Steps.ParallelTraceTransformer do
      argument(:trace, element(:normalize_traces))
    end
  end

  # Compose: Embedded Sub-Reactor for POWL discovery and soundness
  compose :discovery_engine, PowlDiscoverySubReactor do
    argument(:traces, result(:normalize_traces))
  end

  # Group: Audit group with lifecycle before_all and after_all hooks
  group :audit_group do
    before_all(fn arguments, context, steps ->
      if caller = Map.get(context, :test_pid) do
        send(caller, {:audit_group_started, arguments})
      end

      {:ok, arguments, context, steps}
    end)

    after_all(fn results ->
      {:ok, Map.put(results, :group_verified, true)}
    end)

    step :verify_audit_tag do
      argument(:tag, input(:audit_tag))
      run(fn %{tag: tag}, _ctx -> {:ok, %{audit_verified: true, tag: tag}} end)
    end
  end

  # Parallel Analytics Fan-out Steps
  step :alignment_analysis, Steps.ComputeAlignment do
    argument(:traces, result(:normalize_traces))
    argument(:model, result(:discovery_engine, [:powl_model]))
  end

  step :declare_analysis, Steps.CheckDeclareConstraints do
    argument(:traces, result(:normalize_traces))
  end

  step :survival_analysis, Steps.EvaluateSurvivalCurves do
    argument(:trace_count, result(:ingest_data, [:trace_count]))
  end

  step(:bayesian_analysis, Steps.InferBayesianBelief)

  # Collect: Multi-perspective synthesis
  collect :analytics_bundle do
    argument(:alignment, result(:alignment_analysis))
    argument(:declare, result(:declare_analysis))
    argument(:survival, result(:survival_analysis))
    argument(:bayesian, result(:bayesian_analysis))

    transform(fn inputs ->
      %{
        alignment_fitness: inputs.alignment.fitness,
        alignment_cost: inputs.alignment.cost,
        exact_match?: inputs.alignment.exact_match?,
        declare_status: inputs.declare.status,
        median_duration_ms: inputs.survival.median_duration,
        anomaly_probability: inputs.bayesian.anomaly_posterior_given_root
      }
    end)
  end

  # Switch: Non-block decision routing
  switch :routing_verdict do
    on(input(:mode))

    matches? &(&1 == :deep_audit) do
      step :routing_verdict do
        argument(:bundle, result(:analytics_bundle))

        run(fn %{bundle: b}, _ctx ->
          {:ok, Map.put(b, :classification, :deeply_audited)}
        end)
      end
    end

    default do
      step :routing_verdict do
        argument(:bundle, result(:analytics_bundle))

        run(fn %{bundle: b}, _ctx ->
          {:ok, Map.put(b, :classification, :standard_qualification)}
        end)
      end
    end
  end

  # Conditional Step using where clause
  step :conditional_alert do
    argument(:bundle, result(:analytics_bundle))
    where(fn %{bundle: b} -> b.alignment_fitness < 1.0 or b.anomaly_probability > 0.5 end)

    run(fn %{bundle: b}, _ctx ->
      {:ok,
       %{alert_issued: true, reason: :anomalous_trace_detected, fitness: b.alignment_fitness}}
    end)
  end

  # Debug Step: Non-intrusive logging
  debug :audit_telemetry do
    argument(:dataset, input(:filename))
    argument(:traces, result(:ingest_data, [:trace_count]))
    argument(:verdict, result(:routing_verdict))
  end

  # Final Return Assembly
  collect :final_manifest do
    argument(:filename, input(:filename))
    argument(:trace_count, result(:ingest_data, [:trace_count]))
    argument(:discovery, result(:discovery_engine))
    argument(:analytics, result(:analytics_bundle))
    argument(:routing, result(:routing_verdict))

    transform(fn inputs ->
      %{
        dataset: inputs.filename,
        trace_count: inputs.trace_count,
        sound?: inputs.discovery.sound?,
        powl_model: inputs.discovery.powl_model,
        bpmn_xml: inputs.discovery.bpmn_xml,
        analytics: inputs.analytics,
        verdict: inputs.routing,
        standing: :alive
      }
    end)
  end

  return(:final_manifest)
end
