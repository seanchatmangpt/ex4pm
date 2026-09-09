defmodule Ex4pmCore.CapsuleGraph.Calibration.Standing do
  @moduledoc false

  @spec derive(atom(), [atom()], non_neg_integer(), pos_integer()) :: atom()
  def derive(decision, outcomes, independent_clusters, required_clusters)
      when is_list(outcomes) and is_integer(independent_clusters) and independent_clusters >= 0 and
             is_integer(required_clusters) and required_clusters > 0 do
    cond do
      :fail in outcomes -> :build_broken
      independent_clusters < required_clusters -> :unknown
      decision == :accept_bounded -> :partial_alive
      decision == :reject -> :build_broken
      true -> :unknown
    end
  end
end
