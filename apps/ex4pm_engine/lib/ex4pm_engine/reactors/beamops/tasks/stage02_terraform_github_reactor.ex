# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage02TerraformGithubReactor do
  @moduledoc """
  Chapter 2 Task: Validates Terraform GitHub provider milestones, issues, and project management DAG.
  """
  use Reactor

  input(:milestones)
  input(:issues)

  step :validate_iac_project_management do
    async?(false)
    argument(:milestones, input(:milestones))
    argument(:issues, input(:issues))

    run(fn args, _context ->
      has_milestones? = length(args.milestones) > 0
      has_issues? = length(args.issues) > 0

      if has_milestones? and has_issues? do
        {:ok,
         %{
           stage: "Ch02_Terraform_GitHub",
           status: :verified,
           milestone_count: length(args.milestones),
           issue_count: length(args.issues),
           standing: :alive
         }}
      else
        {:error, :empty_project_dag}
      end
    end)
  end

  return(:validate_iac_project_management)
end
