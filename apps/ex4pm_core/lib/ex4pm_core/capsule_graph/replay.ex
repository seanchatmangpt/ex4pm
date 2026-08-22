defmodule Ex4pmCore.CapsuleGraph.Replay do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.{Digest, Receipt}

  def verify(%Receipt{} = receipt) do
    if Digest.sha256(Receipt.body(receipt)) == receipt.digest do
      {:ok, :match}
    else
      {:error, {:refused, :capsule_receipt_mismatch}}
    end
  end

  def verify(_), do: {:error, {:refused, :invalid_capsule_receipt}}
end
