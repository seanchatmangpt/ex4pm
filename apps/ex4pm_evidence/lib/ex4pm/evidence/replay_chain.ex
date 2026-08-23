defmodule Ex4pm.Evidence.Replay.Chain do
  @moduledoc "Chain-aware replay verification for pending/outcome receipt correspondence."

  alias Ex4pm.Evidence.{Receipt, Replay, Store}
  alias Ex4pm.Refusal

  def verify(%Receipt{phase: :pending} = receipt, _store) do
    Replay.verify(receipt)
  end

  def verify(%Receipt{phase: :outcome, parent_hash: parent_hash} = outcome, store)
      when is_binary(parent_hash) do
    with {:ok, %{replay: :match}} <- Replay.verify(outcome),
         {:ok, parent} <- fetch_parent(parent_hash, store),
         {:ok, %{replay: :match}} <- Replay.verify(parent),
         :ok <- admit_parent(parent, outcome) do
      {:ok,
       %{
         receipt: outcome,
         parent: parent,
         standing: outcome.standing || :partial_alive,
         replay: :chain_match
       }}
    end
  end

  def verify(%Receipt{phase: :outcome} = outcome, _store) do
    {:error,
     Refusal.new(:receipt_parent_missing, "outcome receipt does not name a pending parent",
       details: %{receipt_hash: outcome.hash}
     )}
  end

  def verify(other, _store) do
    {:error,
     Refusal.new(:invalid_receipt, "receipt chain replay requires a receipt struct",
       subject: other
     )}
  end

  defp fetch_parent(parent_hash, store) do
    case Store.get(parent_hash, store) do
      {:ok, %Receipt{phase: :pending} = parent} ->
        {:ok, parent}

      {:ok, %Receipt{} = parent} ->
        {:error,
         Refusal.new(:receipt_parent_invalid_phase, "outcome parent must be a pending receipt",
           details: %{parent_hash: parent_hash, phase: parent.phase}
         )}

      :error ->
        {:error,
         Refusal.new(
           :receipt_parent_not_found,
           "outcome parent is not present in the receipt ledger",
           details: %{parent_hash: parent_hash}
         )}
    end
  end

  defp admit_parent(parent, outcome) do
    mismatches =
      [
        {:subject_hash, parent.subject_hash, outcome.subject_hash},
        {:operation, parent.operation, outcome.operation},
        {:authority_hash, parent.authority_hash, outcome.authority_hash}
      ]
      |> Enum.reject(fn {_field, left, right} -> left == right end)
      |> Map.new(fn {field, left, right} -> {field, %{pending: left, outcome: right}} end)

    if map_size(mismatches) == 0 do
      :ok
    else
      {:error,
       Refusal.new(
         :receipt_parent_mismatch,
         "outcome receipt does not correspond to its pending parent",
         details: %{parent_hash: parent.hash, receipt_hash: outcome.hash, mismatches: mismatches}
       )}
    end
  end
end
