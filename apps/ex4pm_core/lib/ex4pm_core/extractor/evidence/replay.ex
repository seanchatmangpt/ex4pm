defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Replay do
  @moduledoc false

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.{Digest, Receipt}

  def verify(%Receipt{} = receipt) do
    expected =
      Digest.of(%{
        extractor: receipt.extractor,
        source_digest: receipt.source_digest,
        output_digest: receipt.output_digest,
        authority: receipt.authority
      })

    if expected == receipt.body_digest do
      {:ok, :match}
    else
      {:error, {:refused, :receipt_mismatch}}
    end
  end

  def verify(_), do: {:error, {:refused, :invalid_receipt}}
end
