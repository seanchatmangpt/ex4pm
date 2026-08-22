defmodule Ex4pmCore.CapsuleGraph.Calibration.Source do
  @moduledoc false

  @enforce_keys [:producer, :run, :artifact, :family, :fingerprint]
  defstruct [:producer, :run, :artifact, :family, :fingerprint]

  @spec new(String.t(), String.t(), String.t(), String.t()) :: {:ok, struct()} | {:error, term()}
  def new(producer, run, artifact, family)
      when is_binary(producer) and is_binary(run) and is_binary(artifact) and is_binary(family) do
    parts = [producer, run, artifact, family]

    if Enum.all?(parts, &(String.trim(&1) != "")) do
      fingerprint = :crypto.hash(:sha256, :erlang.term_to_binary(parts, [:deterministic])) |> Base.encode16(case: :lower)
      {:ok, %__MODULE__{producer: producer, run: run, artifact: artifact, family: family, fingerprint: fingerprint}}
    else
      {:error, {:refused, :incomplete_evidence_source}}
    end
  end

  def new(_, _, _, _), do: {:error, {:refused, :incomplete_evidence_source}}
end
