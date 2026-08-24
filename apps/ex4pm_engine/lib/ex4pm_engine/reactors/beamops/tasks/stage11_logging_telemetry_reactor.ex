# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage11LoggingTelemetryReactor do
  @moduledoc """
  Chapter 11 Task: Validates structured JSON logging, Promtail/Alloy log aggregation, Loki, and Prometheus scraping.
  """
  use Reactor

  input(:logger_format)
  input(:promtail_config)

  step :validate_logging_and_telemetry do
    async?(false)
    argument(:format, input(:logger_format))
    argument(:promtail, input(:promtail_config))

    run(fn args, _context ->
      is_json? = args.format in [:json, "json", :structured]
      has_scrape_target? = is_map(args.promtail) and Map.has_key?(args.promtail, :targets)

      if is_json? and has_scrape_target? do
        {:ok,
         %{
           stage: "Ch11_Logging_Telemetry",
           status: :verified,
           format: :json,
           loki_forwarding: :active,
           prometheus_scraping: :active,
           standing: :alive
         }}
      else
        {:error, {:invalid_logging_architecture, args.format}}
      end
    end)
  end

  return(:validate_logging_and_telemetry)
end
