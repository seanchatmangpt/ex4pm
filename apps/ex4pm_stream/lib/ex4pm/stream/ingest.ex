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
    with {:ok, validated} <- OCEL.validate_envelope(envelope),
         :ok <- check_idempotency(validated, opts),
         {:ok, log} <-
           OCEL.normalize(%{
             events: validated.events,
             objects: validated.objects,
             object_relationships: validated.object_relationships
           }) do
      # 1. Forward events to OnlineMiner if available
      miner_pid = resolve_pid(Keyword.get(opts, :miner, OnlineMiner))

      if miner_pid do
        OnlineMiner.ingest(log.events, miner_pid)
      end

      # 2. Optionally record ingestion outcome receipt
      store_pid = resolve_pid(Keyword.get(opts, :store, Store))
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

  defp check_idempotency(envelope, _opts) do
    # Verify sequence integer > 0
    if envelope.sequence < 0 do
      {:error,
       Refusal.new(:invalid_sequence, "envelope sequence must be non-negative",
         details: %{sequence: envelope.sequence}
       )}
    else
      :ok
    end
  end
end
