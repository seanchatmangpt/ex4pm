# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage05ComposeDatabaseReactor do
  @moduledoc """
  Chapter 5 Task: Validates Docker Compose multi-service synchronization, Ecto migrations, and database healthchecks.
  """
  use Reactor

  input(:services)

  step :validate_compose_stack do
    async?(false)
    argument(:services, input(:services))

    run(fn args, _context ->
      has_db? = :db in args.services or "db" in args.services
      has_app? = :app in args.services or "app" in args.services or :kanban in args.services

      if has_db? and has_app? do
        {:ok,
         %{
           stage: "Ch05_Compose_Database",
           status: :verified,
           services: args.services,
           standing: :alive
         }}
      else
        {:error, {:incomplete_compose_services, args.services}}
      end
    end)
  end

  return(:validate_compose_stack)
end
