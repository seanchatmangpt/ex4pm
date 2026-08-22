defmodule Ex4pmCore.CapsuleGraph.Subject do
  @moduledoc false

  @enforce_keys [:repository, :sha]
  defstruct [:repository, :sha]

  @sha_pattern ~r/\A[0-9a-f]{40}\z/

  def new(repository, sha) when is_binary(repository) and is_binary(sha) do
    if valid_repository?(repository) and Regex.match?(@sha_pattern, sha) do
      {:ok, %__MODULE__{repository: repository, sha: sha}}
    else
      {:error, {:refused, :invalid_exact_subject, {repository, sha}}}
    end
  end

  def new(repository, sha), do: {:error, {:refused, :invalid_exact_subject, {repository, sha}}}

  def same?(%__MODULE__{} = left, %__MODULE__{} = right), do: left == right

  defp valid_repository?(repository) do
    case String.split(repository, "/", parts: 3) do
      [owner, name] -> owner != "" and name != "" and not String.contains?(repository, ~r/\s/)
      _ -> false
    end
  end
end
