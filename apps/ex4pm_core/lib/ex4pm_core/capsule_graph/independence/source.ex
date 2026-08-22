defmodule Ex4pmCore.CapsuleGraph.Independence.Source do
  @moduledoc false

  @enforce_keys [:subject, :producer, :run, :artifact, :family]
  defstruct [:subject, :producer, :run, :artifact, :family, :id]

  def new(subject, producer, run, artifact, family)
      when is_binary(subject) and is_binary(producer) and is_binary(run) and
             is_binary(artifact) and is_binary(family) do
    with :ok <- exact_subject(subject),
         true <- Enum.all?([producer, run, artifact, family], &nonblank?/1) do
      fields = [subject, producer, run, artifact, family]
      id = :crypto.hash(:sha256, Enum.join(fields, "\u0000")) |> Base.encode16(case: :lower)
      {:ok, %__MODULE__{subject: subject, producer: producer, run: run, artifact: artifact, family: family, id: id}}
    else
      false -> {:error, {:refused, :incomplete_evidence_source}}
      {:error, _} = error -> error
    end
  end

  def new(_, _, _, _, _), do: {:error, {:refused, :invalid_evidence_source}}

  defp exact_subject(subject) do
    case Regex.run(~r/^[^\s\/]+\/[^\s@]+@[0-9a-f]{40}$/, subject) do
      nil -> {:error, {:refused, :inexact_subject}}
      _ -> :ok
    end
  end

  defp nonblank?(value), do: String.trim(value) != ""
end
