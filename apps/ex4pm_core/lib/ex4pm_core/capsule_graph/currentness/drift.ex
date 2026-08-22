defmodule Ex4pmCore.CapsuleGraph.Currentness.Drift do
  @moduledoc false

  def classify(before_ctx, after_ctx) do
    []
    |> maybe_add(:subject, before_ctx.subject != after_ctx.subject)
    |> maybe_add(:generation, before_ctx.generation != after_ctx.generation)
    |> maybe_add(:cut, before_ctx.cut_id != after_ctx.cut_id)
    |> maybe_add(:policy, before_ctx.policy_digest != after_ctx.policy_digest)
    |> maybe_add(:frontier, before_ctx.frontier_digest != after_ctx.frontier_digest)
    |> Enum.reverse()
  end

  defp maybe_add(acc, axis, true), do: [axis | acc]
  defp maybe_add(acc, _axis, false), do: acc
end
