defmodule Ex4pmCore.CapsuleGraph.Currentness.Context do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Digest

  @enforce_keys [:subject, :generation, :cut_id, :policy_digest, :frontier_digest]
  defstruct [:subject, :generation, :cut_id, :policy_digest, :frontier_digest]

  def new(subject, generation, cut_id, policy_digest, frontier_digest)
      when is_integer(generation) and generation >= 0 and is_binary(cut_id) and cut_id != "" and
             is_binary(policy_digest) and policy_digest != "" and is_binary(frontier_digest) and frontier_digest != "" do
    context = %__MODULE__{subject: subject, generation: generation, cut_id: cut_id, policy_digest: policy_digest, frontier_digest: frontier_digest}
    {:ok, context, digest(context)}
  end

  def new(_, _, _, _, _), do: {:error, {:refused, :invalid_context}}
  def digest(%__MODULE__{} = context), do: Digest.sha256(context)
end
