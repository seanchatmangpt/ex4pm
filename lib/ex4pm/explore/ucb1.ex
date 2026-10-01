defmodule Ex4pm.Explore.UCB1 do
  @moduledoc false

  # Tuple arms: {id, reward, pulls}.
  def choose(arms, total_pulls) do
    Enum.max_by(arms, fn {_id, reward, pulls} ->
      if pulls == 0,
        do: :infinity,
        else: reward / pulls + :math.sqrt(2.0 * :math.log(max(total_pulls, 1)) / pulls)
    end)
  end

  # Map arms: %{reward: _, trials: _}.
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
