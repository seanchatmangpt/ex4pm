defmodule Ex4pm.Evidence.Batch do
  @moduledoc """
  Durable, resumable batch ledger (hand-written; classification:
  pat-wrapper-over-admitted-data per `docs/PRD-v26.9.10.md` R2, matching
  beam4pm's own `BeamPM.Contracts` precedent).

  Models exactly the shape the RCA specified as missing: a batch of
  admitted/qualified/published/merged work counted against a `target`,
  carrying a coded `Ex4pm.Standing.Coded` standing.

  ex4pm itself does not persist this anywhere -- no database, no file
  store beyond what `Ex4pm.Evidence.Store` already does for receipts.
  This is a data-shape + transition-logic contract, not a new storage
  subsystem; persistence is the caller's job.
  """

  alias Ex4pm.Standing.Coded

  @enforce_keys [:id, :base, :target]
  defstruct [
    :id,
    :base,
    :target,
    :next_cell,
    :standing,
    admitted: 0,
    qualified: 0,
    published: 0,
    merged: 0
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          base: String.t(),
          target: non_neg_integer(),
          admitted: non_neg_integer(),
          qualified: non_neg_integer(),
          published: non_neg_integer(),
          merged: non_neg_integer(),
          next_cell: String.t() | nil,
          standing: Coded.t() | nil
        }

  @doc "Starts a new batch at zero counters, no standing set (still open/unclosed)."
  @spec new(String.t(), non_neg_integer()) :: t()
  def new(id, target) when is_binary(id) and is_integer(target) and target >= 0 do
    %__MODULE__{id: id, base: id, target: target, standing: nil}
  end

  @doc """
  Bumps `:admitted`/`:qualified`/`:published`/`:merged` counters by the
  delta amounts given in `delta`, and updates `:next_cell` when provided.
  Unspecified keys are left untouched.
  """
  @spec advance(t(), map()) :: t()
  def advance(%__MODULE__{} = batch, delta) when is_map(delta) do
    batch
    |> bump(:admitted, delta)
    |> bump(:qualified, delta)
    |> bump(:published, delta)
    |> bump(:merged, delta)
    |> maybe_set_next_cell(delta)
  end

  defp bump(batch, key, delta) do
    case Map.get(delta, key) do
      nil -> batch
      amount when is_integer(amount) -> Map.update!(batch, key, &(&1 + amount))
    end
  end

  defp maybe_set_next_cell(batch, delta) do
    case Map.get(delta, :next_cell) do
      nil -> batch
      next_cell -> %{batch | next_cell: next_cell}
    end
  end

  @doc """
  RCA rule 2: "if active batch exists, NEVER start another batch,
  continue it." A batch whose own standing is already closed (`:alive`
  or `:build_broken`) must not be silently re-opened -- resuming it is
  prohibited. Any other batch (no standing yet, or a non-closed
  standing) may be continued.
  """
  @spec resume(t()) :: {:continue, t()} | {:prohibited, String.t()}
  def resume(%__MODULE__{standing: %Coded{standing: closed}} = batch)
      when closed in [:alive, :build_broken] do
    {:prohibited,
     "batch #{batch.id} is already closed (#{Coded.to_string(batch.standing)}); resuming a closed batch is prohibited -- start a new batch instead"}
  end

  def resume(%__MODULE__{} = batch), do: {:continue, batch}

  @doc "True when qualified work has met or exceeded the batch's target."
  @spec quota_met?(t()) :: boolean()
  def quota_met?(%__MODULE__{qualified: qualified, target: target}), do: qualified >= target

  @doc """
  Closes the batch: `ALIVE[<id>_50]`-shaped coded standing when quota is
  met, else `BUILD_BROKEN[TAKT_SHORTFALL]`.
  """
  @spec close(t()) :: t()
  def close(%__MODULE__{} = batch) do
    if quota_met?(batch) do
      %{batch | standing: Coded.new(:alive, batch.id <> "_50")}
    else
      %{batch | standing: Coded.new(:build_broken, "TAKT_SHORTFALL")}
    end
  end
end
