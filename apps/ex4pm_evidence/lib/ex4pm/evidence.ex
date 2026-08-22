defmodule Ex4pm.Evidence.Receipt do
  @moduledoc "Receipted identity, authority, consequence, replay, and standing."

  @enforce_keys [:phase, :subject_hash, :operation, :hash]
  defstruct [
    :phase,
    :subject_hash,
    :operation,
    :hash,
    :parent_hash,
    :authority_hash,
    :artifact_hash,
    :standing,
    :started_at,
    :finished_at,
    metadata: %{}
  ]

  alias Ex4pm.Core.Hash

  def pending(subject_hash, operation, authority, metadata \\ %{}) do
    started_at = DateTime.utc_now() |> DateTime.to_iso8601()
    authority_hash = if is_nil(authority), do: nil, else: Hash.digest(authority)

    payload = %{
      phase: :pending,
      subject_hash: subject_hash,
      operation: operation,
      authority_hash: authority_hash,
      started_at: started_at,
      metadata: metadata
    }

    %__MODULE__{
      phase: :pending,
      subject_hash: subject_hash,
      operation: operation,
      authority_hash: authority_hash,
      started_at: started_at,
      metadata: metadata,
      standing: :partial_alive,
      hash: Hash.digest(payload)
    }
  end

  def outcome(%__MODULE__{phase: :pending} = pending, result, standing, metadata \\ %{}) do
    finished_at = DateTime.utc_now() |> DateTime.to_iso8601()
    artifact_hash = Hash.digest(result)

    payload = %{
      phase: :outcome,
      parent_hash: pending.hash,
      subject_hash: pending.subject_hash,
      operation: pending.operation,
      authority_hash: pending.authority_hash,
      artifact_hash: artifact_hash,
      standing: standing,
      finished_at: finished_at,
      metadata: metadata
    }

    %__MODULE__{
      phase: :outcome,
      parent_hash: pending.hash,
      subject_hash: pending.subject_hash,
      operation: pending.operation,
      authority_hash: pending.authority_hash,
      artifact_hash: artifact_hash,
      standing: standing,
      started_at: pending.started_at,
      finished_at: finished_at,
      metadata: metadata,
      hash: Hash.digest(payload)
    }
  end
end

defmodule Ex4pm.Evidence.Store do
  @moduledoc "Process-local durable-for-runtime receipt ledger backed by ETS."

  use GenServer

  @table __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def put(receipt, server \\ __MODULE__), do: GenServer.call(server, {:put, receipt})
  def get(hash, server \\ __MODULE__), do: GenServer.call(server, {:get, hash})
  def all(server \\ __MODULE__), do: GenServer.call(server, :all)

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :protected, {:read_concurrency, true}])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:put, %{hash: hash} = receipt}, _from, state) do
    true = :ets.insert(state.table, {hash, receipt})
    {:reply, {:ok, receipt}, state}
  end

  def handle_call({:get, hash}, _from, state) do
    reply =
      case :ets.lookup(state.table, hash) do
        [{^hash, receipt}] -> {:ok, receipt}
        [] -> :error
      end

    {:reply, reply, state}
  end

  def handle_call(:all, _from, state) do
    receipts =
      state.table |> :ets.tab2list() |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.started_at)

    {:reply, receipts, state}
  end
end

defmodule Ex4pm.Evidence.Replay do
  @moduledoc "Independent receipt recomputation for the evidence envelope."

  alias Ex4pm.Core.Hash
  alias Ex4pm.Evidence.Receipt
  alias Ex4pm.Refusal

  def verify(%Receipt{phase: :pending} = receipt) do
    expected =
      Hash.digest(%{
        phase: :pending,
        subject_hash: receipt.subject_hash,
        operation: receipt.operation,
        authority_hash: receipt.authority_hash,
        started_at: receipt.started_at,
        metadata: receipt.metadata
      })

    compare(receipt.hash, expected, receipt)
  end

  def verify(%Receipt{phase: :outcome} = receipt) do
    expected =
      Hash.digest(%{
        phase: :outcome,
        parent_hash: receipt.parent_hash,
        subject_hash: receipt.subject_hash,
        operation: receipt.operation,
        authority_hash: receipt.authority_hash,
        artifact_hash: receipt.artifact_hash,
        standing: receipt.standing,
        finished_at: receipt.finished_at,
        metadata: receipt.metadata
      })

    compare(receipt.hash, expected, receipt)
  end

  def verify(other) do
    {:error,
     Refusal.new(:invalid_receipt, "receipt replay requires a receipt struct", subject: other)}
  end

  defp compare(actual, expected, receipt) do
    if actual == expected do
      {:ok, %{receipt: receipt, standing: receipt.standing || :partial_alive, replay: :match}}
    else
      {:error,
       Refusal.new(:replay_mismatch, "receipt hash does not recompute",
         details: %{actual: actual, expected: expected}
       )}
    end
  end
end

defmodule Ex4pm.Evidence.BRCE do
  @moduledoc "Exclusive receipted DO boundary."

  alias Ex4pm.Evidence.{Receipt, Store}
  alias Ex4pm.Refusal

  def execute(subject_hash, operation, authority, fun, opts \\ []) when is_function(fun, 0) do
    with :ok <- admit(authority, operation) do
      store = Keyword.get(opts, :store, Store)
      metadata = Map.new(Keyword.get(opts, :metadata, %{}))
      pending = Receipt.pending(subject_hash, operation, authority, metadata)

      with {:ok, _} <- persist(pending, store, :pending_receipt_persistence_failed) do
        invoke_and_finalize(pending, fun, store, metadata)
      end
    end
  end

  def admit(authority, operation) when is_map(authority) do
    capabilities = Map.get(authority, :capabilities) || Map.get(authority, "capabilities") || []
    allowed = Map.get(authority, :allow) || Map.get(authority, "allow") || []
    operation_text = operation_text(operation)

    if :do in capabilities or "do" in capabilities or operation in allowed or
         operation_text in allowed do
      :ok
    else
      {:error,
       Refusal.new(:authority_denied, "authority does not admit requested DO operation",
         details: %{operation: operation, operation_text: operation_text}
       )}
    end
  end

  def admit(_authority, operation) do
    {:error,
     Refusal.new(:authority_required, "DO requires an explicit authority map",
       details: %{operation: operation}
     )}
  end

  defp operation_text(operation) when is_binary(operation), do: operation
  defp operation_text(operation) when is_atom(operation), do: Atom.to_string(operation)
  defp operation_text(operation), do: inspect(operation)

  defp invoke_and_finalize(pending, fun, store, metadata) do
    try do
      result = fun.()
      outcome = Receipt.outcome(pending, result, :alive, Map.put(metadata, :result, :ok))

      with {:ok, _} <- persist(outcome, store, :outcome_receipt_persistence_failed) do
        {:ok, %{result: result, pending: pending, receipt: outcome}}
      end
    rescue
      exception ->
        failure = %{exception: Exception.message(exception), module: exception.__struct__}

        finalize_failure(
          pending,
          failure,
          exception,
          store,
          Map.put(metadata, :result, :exception)
        )
    catch
      kind, reason ->
        failure = %{kind: kind, reason: inspect(reason)}

        finalize_failure(
          pending,
          failure,
          {kind, reason},
          store,
          Map.put(metadata, :result, :caught)
        )
    end
  end

  defp finalize_failure(pending, failure, original_error, store, metadata) do
    outcome = Receipt.outcome(pending, failure, :blocked, metadata)

    case persist(outcome, store, :outcome_receipt_persistence_failed) do
      {:ok, _} ->
        {:error, %{error: original_error, pending: pending, receipt: outcome}}

      {:error, %Refusal{} = refusal} ->
        {:error, %{refusal | details: Map.put(refusal.details, :original_failure, failure)}}
    end
  end

  defp persist(receipt, store, code) do
    case safe_put(receipt, store) do
      {:ok, _} ->
        {:ok, receipt}

      {:error, reason} ->
        {:error,
         Refusal.new(code, "receipt persistence failed; standing cannot advance",
           details: %{
             phase: receipt.phase,
             receipt_hash: receipt.hash,
             subject_hash: receipt.subject_hash,
             operation: receipt.operation,
             do_attempted: receipt.phase == :outcome,
             reason: inspect(reason)
           }
         )}
    end
  end

  defp safe_put(receipt, store) do
    try do
      case Store.put(receipt, store) do
        {:ok, _} = ok -> ok
        other -> {:error, other}
      end
    rescue
      exception -> {:error, {:exception, exception.__struct__, Exception.message(exception)}}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end
end
