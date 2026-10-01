defmodule Ex4pm.Explore.ConstraintSolver do
  @moduledoc false

  def solve(domains, constraints) when is_map(domains) and is_list(constraints) do
    variables = Map.keys(domains)
    search(variables, domains, constraints, %{})
  end

  defp search([], _domains, constraints, assignment) do
    if Enum.all?(constraints, & &1.(assignment)), do: {:ok, assignment}, else: :no_solution
  end

  defp search([var | rest], domains, constraints, assignment) do
    domains
    |> Map.fetch!(var)
    |> Enum.reduce_while(:no_solution, fn value, _ ->
      next = Map.put(assignment, var, value)
      if consistent?(constraints, next) do
        case search(rest, domains, constraints, next) do
          {:ok, _} = found -> {:halt, found}
          :no_solution -> {:cont, :no_solution}
        end
      else
        {:cont, :no_solution}
      end
    end)
  end

  defp consistent?(constraints, assignment), do: Enum.all?(constraints, fn f -> f.(assignment) != false end)
end
