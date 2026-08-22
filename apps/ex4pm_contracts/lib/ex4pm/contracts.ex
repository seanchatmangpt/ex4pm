defmodule Ex4pm.Contracts do
  @moduledoc "Canonical public ontology, SHACL, WIT, and receipt-schema contract inventory."

  alias Ex4pm.Core.Hash
  alias Ex4pm.Refusal

  @contract_version "0.1.0"

  @artifacts %{
    ontology: "ontology/ex4pm.ttl",
    shacl: "shacl/ex4pm-shapes.ttl",
    wit: "wit/ex4pm.wit",
    receipt_schema: "schema/receipt.schema.json"
  }

  @required %{
    ontology: ["ex4pm:EventLog", "ex4pm:ProcessModel", "ex4pm:Receipt", "ex4pm:Authority"],
    shacl: ["sh:NodeShape", "ex4pm:EventShape", "ex4pm:ReceiptShape"],
    wit: ["world ex4pm-engine", "discover:", "conform:", "simulate:"],
    receipt_schema: ["subject_hash", "operation", "standing", "artifact_hash"]
  }

  def version, do: @contract_version

  def artifacts do
    Map.new(@artifacts, fn {id, relative_path} -> {id, artifact_path(relative_path)} end)
  end

  def manifest do
    @artifacts
    |> Enum.sort()
    |> Enum.reduce_while({:ok, %{}}, fn {id, relative_path}, {:ok, acc} ->
      path = artifact_path(relative_path)

      case File.read(path) do
        {:ok, bytes} ->
          entry = %{
            id: id,
            path: relative_path,
            size: byte_size(bytes),
            hash: Hash.digest(bytes),
            version: @contract_version
          }

          {:cont, {:ok, Map.put(acc, id, entry)}}

        {:error, reason} ->
          {:halt,
           {:error,
            Refusal.new(:contract_artifact_missing, "canonical contract artifact is unavailable",
              details: %{id: id, path: relative_path, reason: reason}
            )}}
      end
    end)
  end

  def verify do
    with {:ok, manifest} <- manifest(),
         :ok <- verify_required_terms() do
      {:ok,
       %{
         version: @contract_version,
         artifacts: manifest,
         contract_hash: Hash.digest(manifest),
         standing: :alive
       }}
    end
  end

  def read(id) when is_atom(id) do
    with {:ok, relative_path} <- fetch_artifact(id),
         {:ok, bytes} <- File.read(artifact_path(relative_path)) do
      {:ok, bytes}
    else
      :error ->
        {:error,
         Refusal.new(:unknown_contract_artifact, "contract artifact identity is unknown",
           details: %{id: id}
         )}

      {:error, reason} when not is_struct(reason, Refusal) ->
        {:error,
         Refusal.new(:contract_artifact_missing, "contract artifact cannot be read",
           details: %{id: id, reason: reason}
         )}

      {:error, %Refusal{} = refusal} ->
        {:error, refusal}
    end
  end

  defp verify_required_terms do
    Enum.reduce_while(@required, :ok, fn {id, required_terms}, :ok ->
      with {:ok, bytes} <- read(id) do
        missing = Enum.reject(required_terms, &String.contains?(bytes, &1))

        if missing == [] do
          {:cont, :ok}
        else
          {:halt,
           {:error,
            Refusal.new(
              :contract_terms_missing,
              "canonical contract artifact lacks required terms",
              details: %{id: id, missing: missing}
            )}}
        end
      else
        error -> {:halt, error}
      end
    end)
  end

  defp fetch_artifact(id) do
    case Map.fetch(@artifacts, id) do
      {:ok, path} -> {:ok, path}
      :error -> :error
    end
  end

  defp artifact_path(relative_path) do
    Application.app_dir(:ex4pm_contracts, Path.join("priv", relative_path))
  end
end
