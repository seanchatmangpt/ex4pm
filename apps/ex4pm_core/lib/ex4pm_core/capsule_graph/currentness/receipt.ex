defmodule Ex4pmCore.CapsuleGraph.Currentness.Receipt do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Digest

  def issue(admission, authority \\ :construct) do
    body = %{
      attempt_id: admission.attempt.id,
      context_digest: Ex4pmCore.CapsuleGraph.Currentness.Context.digest(admission.context),
      standing: admission.standing,
      authority: authority,
      actuation_performed: false
    }

    %{schema: "ex4pm.capsule-currentness/v1", body: body, digest: Digest.sha256(body)}
  end

  def replay(%{schema: "ex4pm.capsule-currentness/v1", body: body, digest: digest}) do
    body.actuation_performed == false and body.authority in [:observe, :select, :construct, :verify] and Digest.sha256(body) == digest
  end

  def replay(_), do: false
end
