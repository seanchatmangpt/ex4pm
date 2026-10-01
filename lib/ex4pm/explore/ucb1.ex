defmodule Ex4pm.Explore.UCB1 do
  @moduledoc false
  def choose(arms, total_pulls) do
    Enum.max_by(arms, fn {_id, reward, pulls} ->
      if pulls == 0, do: :infinity, else: reward / pulls + :math.sqrt(2.0 * :math.log(max(total_pulls, 1)) / pulls)
    end)
  end
end
