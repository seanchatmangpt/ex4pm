# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.PromExAuditReactor do
  @moduledoc """
  Reactor Saga sampling telemetry probes, persisting Ash MetricProbe observations,
  and evaluating Alertmanager threshold triggers.
  """
  use Reactor
  alias Ex4pmDomain.BEAMOps.MetricProbe

  input(:metric_samples)
  input(:alert_threshold)

  # Step 1: Ingest & Persist Probes
  step :persist_metric_probes do
    async?(false)
    argument(:samples, input(:metric_samples))
    argument(:threshold, input(:alert_threshold))

    run(fn args, _context ->
      probes =
        for sample <- args.samples do
          alert_state = if sample.value > args.threshold, do: :alerting, else: :ok

          {:ok, probe} =
            Ash.create(MetricProbe, %{
              id: "probe_#{sample.name}_#{System.unique_integer([:positive])}",
              name: sample.name,
              category: Map.get(sample, :category, :beam),
              value: sample.value * 1.0,
              labels: Map.get(sample, :labels, %{}),
              sample_timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
              alert_state: alert_state
            })

          probe
        end

      {:ok, probes}
    end)
  end

  # Step 2: Evaluate Alerts
  step :evaluate_alerts do
    async?(false)
    argument(:probes, result(:persist_metric_probes))

    run(fn args, _context ->
      alerting = Enum.filter(args.probes, &(&1.alert_state == :alerting))
      {:ok, %{alert_count: length(alerting), alerting_probes: Enum.map(alerting, & &1.name)}}
    end)
  end

  collect :audit_summary do
    argument(:probes, result(:persist_metric_probes))
    argument(:alerts, result(:evaluate_alerts))

    transform(fn inputs ->
      %{
        total_probes_sampled: length(inputs.probes),
        alert_count: inputs.alerts.alert_count,
        alerting_probes: inputs.alerts.alerting_probes,
        standing: if(inputs.alerts.alert_count == 0, do: :healthy, else: :degraded)
      }
    end)
  end

  return(:audit_summary)
end
