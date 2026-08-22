defmodule Ex4pmCore.CapsuleGraph.Currentness.Subject do
  @moduledoc false
  @enforce_keys [:repository, :sha]
  defstruct [:repository, :sha]

  def new(repository, sha) when is_binary(repository) and is_binary(sha) do
    with true <- Regex.match?(~r/^[^\s\/]+\/[^\s\/]+$/, repository),
         true <- Regex.match?(~r/^[0-9a-f]{40}$/, sha) do
      {:ok, %__MODULE__{repository: repository, sha: sha}}
    else
      _ -> {:error, {:refused, :inexact_subject}}
    end
  end

  def new(_, _), do: {:error, {:refused, :inexact_subject}}
end
