# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage04CiPipelineReactor do
  @moduledoc """
  Chapter 4 Task: Validates GitHub Actions CI pipeline gates (compile, test, format, docker push).
  """
  use Reactor

  input(:ci_steps)

  step :validate_ci_pipeline do
    async?(false)
    argument(:steps, input(:ci_steps))

    run(fn args, _context ->
      required = [:format, :compile, :test, :docker_push]
      missing = Enum.reject(required, &(&1 in args.steps))

      if missing == [] do
        {:ok,
         %{
           stage: "Ch04_CI_Pipeline",
           status: :verified,
           passed_steps: args.steps,
           standing: :alive
         }}
      else
        {:error, {:missing_ci_steps, missing}}
      end
    end)
  end

  return(:validate_ci_pipeline)
end
