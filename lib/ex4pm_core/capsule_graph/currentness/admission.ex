defmodule Ex4pmCore.CapsuleGraph.Currentness.Admission do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Currentness.{Context, Lease}

  def admit(attempt, current_context, witness, now) do
    current_digest = Context.digest(current_context)

    cond do
      not Lease.active?(attempt.lease, now) ->
        {:error, {:refused, :expired_attempt}}

      attempt.target_digest != current_digest ->
        {:error, {:refused, :stale_target}}

      witness.after_digest != current_digest ->
        {:error, {:refused, :stale_witness}}

      witness.result != :pass ->
        {:error, {:refused, :witness_not_passed}}

      true ->
        {:ok,
         %{attempt: attempt, context: current_context, witness: witness, standing: :partial_alive}}
    end
  end
end
