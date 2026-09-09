# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage03DockerReleaseReactor do
  @moduledoc """
  Chapter 3 Task: Validates Phoenix LiveView Kanban mix release inside a multi-stage Dockerfile.
  """
  use Reactor

  input(:docker_stages)
  input(:non_root_user)

  step :validate_docker_release do
    async?(false)
    argument(:stages, input(:docker_stages))
    argument(:user, input(:non_root_user))

    run(fn args, _context ->
      has_builder? = :builder in args.stages or "builder" in args.stages
      has_runner? = :runner in args.stages or "runner" in args.stages
      is_non_root? = args.user not in ["root", 0, nil]

      if has_builder? and has_runner? and is_non_root? do
        {:ok,
         %{
           stage: "Ch03_Docker_Release",
           status: :verified,
           stages: args.stages,
           security_user: args.user,
           standing: :alive
         }}
      else
        {:error, {:insecure_docker_spec, args.stages, args.user}}
      end
    end)
  end

  return(:validate_docker_release)
end
