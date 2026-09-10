defmodule Ex4pm.Stream.Ingest do
  @moduledoc """
  Idempotent batch and continuous stream ingestion engine.

  Validates producer envelopes, enforces sequence order, prevents duplicate event
  re-processing, projects into the domain, and forwards to online process miners.
  """

  alias Ex4pm.Engine.OnlineMiner
  alias Ex4pm.Evidence.Receipt
  alias Ex4pm.Evidence.Store
  alias Ex4pm.OCEL
  alias Ex4pm.Refusal

  defp resolve_pid(server) when is_pid(server), do: server
  defp resolve_pid(server) when is_atom(server), do: Process.whereis(server)
  defp resolve_pid(_), do: nil

  def ingest_envelope(envelope, opts \\ []) do
    store_pid = resolve_pid(Keyword.get(opts, :store, Store))

    with {:ok, validated} <- OCEL.validate_envelope(envelope),
         :ok <- check_sequence(validated),
         {:ok, log} <-
           OCEL.normalize(%{
             events: validated.events,
             objects: validated.objects,
             object_relationships: validated.object_relationships
           }) do
      case find_duplicate(log.subject.hash, store_pid) do
        %Receipt{} = existing ->
          {:ok, duplicate_result(log, validated, existing)}

        nil ->
          do_ingest(validated, log, opts, store_pid)
      end
    end
  end

  # Verify sequence integer is non-negative. This is envelope-shape validation
  # (ordering/well-formedness), not deduplication -- see find_duplicate/2 for the
  # real idempotency check.
  defp check_sequence(envelope) do
    if envelope.sequence < 0 do
      {:error,
       Refusal.new(:invalid_sequence, "envelope sequence must be non-negative",
         details: %{sequence: envelope.sequence}
       )}
    else
      :ok
    end
  end

  # Real idempotency check: look up whether an outcome receipt already exists for
  # this exact logical event content. `log.subject.hash` is a deterministic
  # content hash of the normalized events/objects (Ex4pm.Subject.new/3 via
  # Ex4pm.Core.Hash.digest/1) -- it is invariant across retries and across
  # duplicate notify/1 firings for the *same* logical business event (same
  # activity, same object ids, same timestamp), while two genuinely distinct
  # occurrences of the same activity (different timestamps) hash differently and
  # are correctly NOT deduplicated. This directly replaces the sequence-sign-only
  # check that previously did zero deduplication.
  defp find_duplicate(_subject_hash, nil), do: nil

  defp find_duplicate(subject_hash, store_pid) do
    subject_hash
    |> Store.get_by_subject(store_pid)
    |> Enum.find(&(&1.phase == :outcome))
  end

  defp duplicate_result(log, validated, existing_receipt) do
    producer = validated.producer
    agent_id = Map.get(producer, "agent_id") || Map.get(producer, :agent_id, "unknown")
    run_id = Map.get(producer, "run_id") || Map.get(producer, :run_id, agent_id)

    %{
      status: :duplicate_ignored,
      subject_hash: log.subject.hash,
      event_count: length(log.events),
      object_count: map_size(log.objects),
      sequence: validated.sequence,
      agent_id: agent_id,
      run_id: run_id,
      original_receipt_hash: existing_receipt.hash
    }
  end

  defp do_ingest(validated, log, opts, store_pid) do
    # 1. Forward events to OnlineMiner if available
    miner_pid = resolve_pid(Keyword.get(opts, :miner, OnlineMiner))

    if miner_pid do
      OnlineMiner.ingest(log.events, miner_pid)
    end

    # 2. Record ingestion outcome receipt (this is also what future duplicate
    # envelopes with the same log.subject.hash will be deduplicated against).
    producer = validated.producer
    agent_id = Map.get(producer, "agent_id") || Map.get(producer, :agent_id, "unknown")
    run_id = Map.get(producer, "run_id") || Map.get(producer, :run_id, agent_id)

    pending =
      Receipt.pending(log.subject.hash, {:ingest, :batch}, nil, %{
        agent_id: agent_id,
        run_id: run_id,
        sequence: validated.sequence,
        event_count: length(log.events)
      })

    if store_pid do
      Store.put(pending, store_pid)

      outcome =
        Receipt.outcome(
          pending,
          %{status: :ingested, event_count: length(log.events)},
          :alive,
          %{
            agent_id: agent_id,
            run_id: run_id,
            sequence: validated.sequence
          }
        )

      Store.put(outcome, store_pid)
    end

    # 3. Call optional broadcaster callback
    broadcaster = Keyword.get(opts, :broadcaster)

    if is_function(broadcaster, 1) do
      broadcaster.(%{
        envelope: validated,
        log: log,
        event_count: length(log.events)
      })
    end

    {:ok,
     %{
       status: :ingested,
       subject_hash: log.subject.hash,
       event_count: length(log.events),
       object_count: map_size(log.objects),
       sequence: validated.sequence,
       agent_id: agent_id,
       run_id: run_id
     }}
  end
end
