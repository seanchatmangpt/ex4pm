defmodule Ex4pm.Explore.UCB1 do
  @moduledoc false

  def select(arms, total_trials) when is_list(arms) and total_trials >= 1 do
    arms
    |> Enum.map(fn arm -> {arm, score(arm, total_trials)} end)
    |> Enum.max_by(fn {_arm, score} -> score end)
    |> elem(0)
  end

  def score(%{trials: 0}, _total_trials), do: :infinity
  def score(%{reward: reward, trials: trials}, total_trials) when trials > 0 do
    reward / trials + :math.sqrt(2.0 * :math.log(total_trials) / trials)
  end
end
