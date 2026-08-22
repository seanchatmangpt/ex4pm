defmodule Ex4pm.Information.Step.Normalize do
  @moduledoc false
  use Reactor.Step

  @impl true
  def run(%{request: request}, _context, _options) do
    Ex4pm.Information.Protocol.normalize(request)
  end
end

defmodule Ex4pm.Information.Step.Admit do
  @moduledoc false
  use Reactor.Step

  @impl true
  def run(%{request: request}, _context, _options) do
    Ex4pm.Information.Registry.admit(request)
  end
end

defmodule Ex4pm.Information.Step.PendingReceipt do
  @moduledoc false
  use Reactor.Step

  alias Ex4pm.Evidence.{Receipt, Store}
  alias Ex4pm.Refusal

  @impl true
  def run(%{admitted: admitted}, _context, _options) do
    pending =
      Receipt.pending(
        admitted.request_hash,
        {:information, admitted.capability},
        nil,
        %{
          protocol: admitted.protocol,
          version: admitted.version,
          request_id: admitted.request_id,
          handler: admitted.handler,
          authority_domain: :observe
        }
      )

    case safe_put(pending) do
      {:ok, _receipt} ->
        {:ok, pending}

      {:error, reason} ->
        {:error,
         Refusal.new(
           :pending_receipt_persistence_failed,
           "pending information receipt was not persisted",
           details: %{reason: inspect(reason, limit: 20, printable_limit: 2_000)}
         )}
    end
  end

  defp safe_put(receipt) do
    try do
      Store.put(receipt)
    rescue
      error -> {:error, {:exception, error.__struct__, Exception.message(error)}}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end
end

defmodule Ex4pm.Information.Step.Execute do
  @moduledoc false
  use Reactor.Step

  alias Ex4pm.Information.Handlers
  alias Ex4pm.Refusal

  @impl true
  def run(%{admitted: admitted}, _context, _options) do
    execution =
      try do
        case Handlers.execute(admitted.handler, admitted) do
          {:ok, result} ->
            %{
              status: :ok,
              standing: result.standing,
              value: result.value,
              refusal: nil,
              error: nil,
              underlying_receipts: result.underlying_receipts,
              provenance: Map.put(result.provenance, :handler_attempted, true)
            }

          {:error, %Refusal{} = refusal} ->
            %{
              status: :refused,
              standing: :unknown,
              value: nil,
              refusal: refusal,
              error: nil,
              underlying_receipts: [],
              provenance: %{handler_attempted: true}
            }

          {:error, reason} ->
            runtime_error(reason)
        end
      rescue
        error ->
          runtime_error(%{
            kind: :exception,
            module: inspect(error.__struct__),
            message: Exception.message(error)
          })
      catch
        kind, reason ->
          runtime_error(%{
            kind: kind,
            detail: inspect(reason, limit: 20, printable_limit: 2_000)
          })
      end

    {:ok, execution}
  end

  defp runtime_error(reason) do
    %{
      status: :error,
      standing: :unknown,
      value: nil,
      refusal: nil,
      error: reason,
      underlying_receipts: [],
      provenance: %{handler_attempted: true}
    }
  end
end

defmodule Ex4pm.Information.Step.OutcomeReceipt do
  @moduledoc false
  use Reactor.Step

  alias Ex4pm.Evidence.{Receipt, Store}
  alias Ex4pm.Refusal

  @impl true
  def run(%{admitted: admitted, pending: pending, execution: execution}, _context, _options) do
    artifact = %{
      status: execution.status,
      standing: execution.standing,
      value: execution.value,
      refusal: execution.refusal,
      error: execution.error,
      underlying_receipts: execution.underlying_receipts
    }

    outcome =
      Receipt.outcome(
        pending,
        artifact,
        execution.standing,
        %{
          protocol: admitted.protocol,
          version: admitted.version,
          request_id: admitted.request_id,
          capability: admitted.capability,
          handler: admitted.handler,
          status: execution.status,
          authority_domain: :observe
        }
      )

    case safe_put(outcome) do
      {:ok, _receipt} ->
        {:ok, outcome}

      {:error, reason} ->
        {:error,
         Refusal.new(
           :outcome_receipt_persistence_failed,
           "terminal information receipt was not persisted",
           details: %{reason: inspect(reason, limit: 20, printable_limit: 2_000)}
         )}
    end
  end

  defp safe_put(receipt) do
    try do
      Store.put(receipt)
    rescue
      error -> {:error, {:exception, error.__struct__, Exception.message(error)}}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end
end

defmodule Ex4pm.Information.Step.Envelope do
  @moduledoc false
  use Reactor.Step

  @impl true
  def run(
        %{admitted: admitted, pending: pending, execution: execution, outcome: outcome},
        _context,
        _options
      ) do
    {:ok, Ex4pm.Information.Protocol.response(admitted, execution, pending, outcome)}
  end
end

defmodule Ex4pm.Information.Flow do
  @moduledoc """
  Default Reactor DAG for all non-trivial ex4pm information requests.

  Admission completes before the pending execution receipt is manufactured.
  Once a handler is attempted, success, refusal, runtime error, exception, throw,
  and exit values are captured as data so the normal path can manufacture a
  terminal outcome receipt.
  """

  use Reactor

  input :request

  step :normalize, Ex4pm.Information.Step.Normalize do
    argument :request, input(:request)
    async? false
    max_retries 0
  end

  step :admit, Ex4pm.Information.Step.Admit do
    argument :request, result(:normalize)
    async? false
    max_retries 0
  end

  step :pending_receipt, Ex4pm.Information.Step.PendingReceipt do
    argument :admitted, result(:admit)
    async? false
    max_retries 0
  end

  step :execute, Ex4pm.Information.Step.Execute do
    argument :admitted, result(:admit)
    wait_for :pending_receipt
    async? false
    max_retries 0
  end

  step :outcome_receipt, Ex4pm.Information.Step.OutcomeReceipt do
    argument :admitted, result(:admit)
    argument :pending, result(:pending_receipt)
    argument :execution, result(:execute)
    async? false
    max_retries 0
  end

  step :envelope, Ex4pm.Information.Step.Envelope do
    argument :admitted, result(:admit)
    argument :pending, result(:pending_receipt)
    argument :execution, result(:execute)
    argument :outcome, result(:outcome_receipt)
    async? false
    max_retries 0
  end

  return :envelope
end
