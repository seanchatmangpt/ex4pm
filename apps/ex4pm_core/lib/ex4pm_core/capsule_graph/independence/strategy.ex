defmodule Ex4pmCore.CapsuleGraph.Independence.Strategy do
  @moduledoc false

  @strategies [:cluster_majority, :diversity_weighted, :minimax_failure]

  def strategies, do: @strategies

  def evaluate(strategy, outcomes, {numerator, denominator}) when strategy in @strategies and is_list(outcomes) do
    pass = Enum.count(outcomes, &(&1 == :pass))
    fail = Enum.count(outcomes, &(&1 == :fail))
    unknown = length(outcomes) - pass - fail

    score =
      case strategy do
        :cluster_majority -> {pass - fail, -unknown}
        :diversity_weighted -> {(pass - fail) * numerator, denominator}
        :minimax_failure -> {if(fail == 0, do: pass, else: -fail), -unknown}
      end

    %{strategy: strategy, score: score, standing: standing(pass, fail, unknown)}
  end

  def evaluate(_, _, _), do: {:error, {:refused, :unknown_evidence_strategy}}

  defp standing(_, fail, _) when fail > 0, do: :build_broken
  defp standing(pass, 0, 0) when pass > 1, do: :partial_alive
  defp standing(_, _, _), do: :unknown
end
