defmodule Ex4pmCore.CapsuleGraph.Currentness.Attempt do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Digest
  @enforce_keys [:subject, :base_digest, :target_digest, :ordinal, :nonce, :lease]
  defstruct [:subject, :base_digest, :target_digest, :ordinal, :nonce, :lease, :id]

  def new(subject, base_digest, target_digest, ordinal, nonce, lease)
      when is_binary(base_digest) and is_binary(target_digest) and is_integer(ordinal) and
             ordinal >= 0 and is_binary(nonce) and nonce != "" do
    body = %{
      subject: subject,
      base_digest: base_digest,
      target_digest: target_digest,
      ordinal: ordinal,
      nonce: nonce,
      lease: lease
    }

    {:ok, struct!(__MODULE__, Map.put(body, :id, Digest.sha256(body)))}
  end

  def new(_, _, _, _, _, _), do: {:error, {:refused, :invalid_attempt}}
end
