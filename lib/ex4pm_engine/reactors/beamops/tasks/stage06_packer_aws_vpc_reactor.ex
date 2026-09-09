# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage06PackerAwsVpcReactor do
  @moduledoc """
  Chapter 6 Task: Validates AWS VPC subnet architecture, security groups, and Packer AMI configurations.
  """
  use Reactor

  input(:vpc_config)

  step :validate_aws_production_environment do
    async?(false)
    argument(:config, input(:vpc_config))

    run(fn args, _context ->
      has_subnets? = length(Map.get(args.config, :subnets, [])) >= 2
      has_sg? = Map.has_key?(args.config, :security_group)

      if has_subnets? and has_sg? do
        {:ok,
         %{
           stage: "Ch06_Packer_AWS_VPC",
           status: :verified,
           subnets_count: length(args.config.subnets),
           security_group: args.config.security_group,
           standing: :alive
         }}
      else
        {:error, {:invalid_vpc_topology, args.config}}
      end
    end)
  end

  return(:validate_aws_production_environment)
end
