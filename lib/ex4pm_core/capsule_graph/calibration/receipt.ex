defmodule Ex4pmCore.CapsuleGraph.Calibration.Receipt do
  @moduledoc false

  @schema "ex4pm.capsule-calibration/v1"

  @spec new(map()) :: map()
  def new(body) when is_map(body) do
    canonical =
      Map.merge(%{schema: @schema, authority: :construct, actuation_performed: false}, body)

    digest = digest(canonical)
    Map.put(canonical, :digest, digest)
  end

  @spec replay(map()) :: :match | {:error, term()}
  def replay(
        %{schema: @schema, authority: authority, actuation_performed: false, digest: expected} =
          receipt
      )
      when authority in [:observe, :select, :construct, :verify] do
    actual = receipt |> Map.delete(:digest) |> digest()
    if actual == expected, do: :match, else: {:error, {:refused, :receipt_replay_mismatch}}
  end

  def replay(_), do: {:error, {:refused, :invalid_or_actuating_receipt}}

  defp digest(term) do
    :crypto.hash(:sha256, :erlang.term_to_binary(term, [:deterministic]))
    |> Base.encode16(case: :lower)
  end
end
