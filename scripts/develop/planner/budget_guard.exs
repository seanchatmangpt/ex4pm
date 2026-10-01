defmodule Ex4pm.Develop.Planner.BudgetGuard do
  @moduledoc false
  def admit!(candidate, budget) do
    cond do
      candidate.cost > budget.cost -> {:refused, :cost_budget}
      candidate.expansions > budget.expansions -> {:refused, :expansion_budget}
      candidate.latency_ms > budget.latency_ms -> {:refused, :latency_budget}
      true -> {:ok, candidate}
    end
  end
end
