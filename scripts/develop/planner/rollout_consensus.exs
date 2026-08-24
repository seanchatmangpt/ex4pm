defmodule Ex4pm.Develop.Planner.RolloutConsensus do
  @moduledoc false
  def agree(runs) do
    grouped = Enum.group_by(runs, & &1.result_digest)
    {digest, members} = Enum.max_by(grouped, fn {digest, members} -> {length(members), digest} end)
    if length(members) * 2 > length(runs), do: {:ok, digest}, else: {:refused, :no_rollout_majority}
  end
end
