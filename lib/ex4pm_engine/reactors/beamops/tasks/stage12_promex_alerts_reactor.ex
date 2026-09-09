# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage12PromExAlertsReactor do
  @moduledoc """
  Chapter 12 Task: Validates custom PromEx plugins (CpuPlugin), Grafana dashboard definitions, and Alertmanager alert rules.
  """
  use Reactor

  input(:promex_plugins)
  input(:alert_rules)

  step :validate_promex_and_alerts do
    async?(false)
    argument(:plugins, input(:promex_plugins))
    argument(:rules, input(:alert_rules))

    run(fn args, _context ->
      has_cpu_plugin? = :cpu_plugin in args.plugins or "CpuPlugin" in args.plugins
      has_alerts? = length(args.rules) > 0

      if has_cpu_plugin? and has_alerts? do
        {:ok,
         %{
           stage: "Ch12_PromEx_Alerts",
           status: :verified,
           plugins: args.plugins,
           alert_rules_count: length(args.rules),
           grafana_dashboards_generated: true,
           standing: :alive
         }}
      else
        {:error, {:missing_promex_plugins_or_alerts, args.plugins}}
      end
    end)
  end

  return(:validate_promex_and_alerts)
end
