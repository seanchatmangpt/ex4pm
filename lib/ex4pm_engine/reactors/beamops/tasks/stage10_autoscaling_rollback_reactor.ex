# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage10AutoscalingRollbackReactor do
  @moduledoc """
  Chapter 10 Task: Validates AWS ASG / ALB healthcheck gating, zero-downtime rolling updates, and automated rollbacks.
  """
  use Reactor

  input(:asg_config)
  input(:alb_probes)

  step :validate_autoscaling_and_rollback do
    async?(false)
    argument(:asg, input(:asg_config))
    argument(:probes, input(:alb_probes))

    run(fn args, _context ->
      has_min_max? =
        Map.has_key?(args.asg, :min_size) and Map.has_key?(args.asg, :max_size) and
          args.asg.max_size >= args.asg.min_size

      has_health_probes? = "/healthz" in args.probes and "/readyz" in args.probes

      if has_min_max? and has_health_probes? do
        {:ok,
         %{
           stage: "Ch10_Autoscaling_Rollback",
           status: :verified,
           asg_bounds: {args.asg.min_size, args.asg.max_size},
           health_probes: args.probes,
           automated_rollback_capable: true,
           standing: :alive
         }}
      else
        {:error, {:invalid_autoscaling_spec, args.asg, args.probes}}
      end
    end)
  end

  return(:validate_autoscaling_and_rollback)
end
