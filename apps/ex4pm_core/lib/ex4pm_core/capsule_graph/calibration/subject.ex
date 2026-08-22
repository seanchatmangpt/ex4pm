defmodule Ex4pmCore.CapsuleGraph.Calibration.Subject do
  @moduledoc false

  @enforce_keys [:repository, :sha]
  defstruct [:repository, :sha]

  @type t :: %__MODULE__{repository: String.t(), sha: String.t()}

  @spec new(String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def new(repository, sha) when is_binary(repository) and is_binary(sha) do
    with true <- Regex.match?(~r/^[^\s\/]+\/[^\s\/]+$/, repository),
         true <- Regex.match?(~r/^[0-9a-f]{40}$/, sha) do
      {:ok, %__MODULE__{repository: repository, sha: sha}}
    else
      _ -> {:error, {:refused, :inexact_subject}}
    end
  end

  def new(_, _), do: {:error, {:refused, :inexact_subject}}

  @spec id(t()) :: String.t()
  def id(%__MODULE__{repository: repository, sha: sha}), do: repository <> "@" <> sha
end
