# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.Chicago.ChicagoSagaRollbackReactor do
  @moduledoc """
  Chicago-style Saga Rollback & Compensation Test Reactor.
  Verifies strict reverse LIFO compensation across multi-step transactions when a fault occurs.
  """
  use Reactor
  alias Ex4pmEngine.Reactors.Chicago.Steps

  input(:saga_id)
  input(:slot_id)
  input(:auth_id)
  input(:amount)
  input(:trigger_fault?)
  input(:fault_reason)

  # Step 1: Reserve Resource Slot (Has Undo & Compensate)
  step :reserve_slot, Steps.ReserveProcessSlot do
    argument(:slot_id, input(:slot_id))
  end

  # Step 2: Financial Authorization (Has Undo & Compensate)
  step :authorize_financials, Steps.AuthorizeFinancialCommitment do
    argument(:auth_id, input(:auth_id))
    argument(:amount, input(:amount))
    wait_for(:reserve_slot)
  end

  # Step 3: Terminal Step with Fault Injection
  step :terminal_actuation, Steps.TerminalFaultyActuation do
    argument(:fail?, input(:trigger_fault?))
    argument(:reason, input(:fault_reason))
    wait_for(:authorize_financials)
  end

  # Collect Successful Saga Manifest
  collect :saga_manifest do
    argument(:saga_id, input(:saga_id))
    argument(:slot, result(:reserve_slot))
    argument(:financials, result(:authorize_financials))
    argument(:terminal, result(:terminal_actuation))

    transform(fn inputs ->
      %{
        saga_id: inputs.saga_id,
        status: :committed,
        slot_reserved: inputs.slot.reserved,
        financials_authorized: inputs.financials.authorized,
        terminal_status: inputs.terminal.status
      }
    end)
  end

  return(:saga_manifest)
end
