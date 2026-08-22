# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.OrderToDeliveryEnterpriseReactor do
  @moduledoc """
  100% Feature-Complete Enterprise Ash Reactor Saga of [BPM25] Figure 2b:
  - `middlewares`: Live IEEE OCEL 2.0 telemetry emitter.
  - `input`: Configurable execution parameters.
  - `step`: Dedicated Step modules with `compensate/4` and `undo/3`.
  - `switch`: Non-block choice graph branching (Express vs. Regular).
  - `where`: Conditional step gating.
  - `collect`: Result aggregation into order manifest.
  - `flunk` / terminal fault injection support for negative verification.
  """
  use Reactor

  middlewares do
    middleware Ex4pmEngine.Reactors.Middlewares.OCELEventMiddleware
  end

  input :order_id
  input :amount
  input :shipping_type
  input :insure?
  input :trigger_terminal_fault?

  # Step 1: Check Credit
  step :check_credit, Ex4pmEngine.Reactors.Steps.EnterpriseSteps.CheckCredit do
    argument :order_id, input(:order_id)
    argument :amount, input(:amount)
  end

  # Step 2: Switch for Express vs Regular Shipping
  switch :shipping_branch do
    on input(:shipping_type)

    matches? &(&1 == :express) do
      step :express_ship, Ex4pmEngine.Reactors.Steps.EnterpriseSteps.ExpressShip do
        argument :order_id, input(:order_id)
        wait_for :check_credit
      end
    end

    default do
      step :regular_ship, Ex4pmEngine.Reactors.Steps.EnterpriseSteps.RegularShip do
        argument :order_id, input(:order_id)
        wait_for :check_credit
      end
    end
  end

  # Step 3: Conditional Insurance via Where clause
  step :add_insurance do
    argument :order_id, input(:order_id)
    argument :insure?, input(:insure?)
    wait_for :shipping_branch
    where fn %{insure?: ins} -> ins == true end
    run fn %{order_id: id}, _ctx -> {:ok, %{insured: true, policy: "POL-#{id}"}} end
    undo fn _res, %{order_id: id}, _ctx ->
      send(self(), {:step_undone, :add_insurance, id})
      :ok
    end
  end

  # Step 4: Terminal Delivery with Fault Injection capability
  step :deliver, Ex4pmEngine.Reactors.Steps.EnterpriseSteps.FaultyTerminalDelivery do
    argument :order_id, input(:order_id)
    argument :trigger_fault?, input(:trigger_terminal_fault?)
    wait_for [:shipping_branch, :add_insurance]
  end

  # Step 5: Collect Final Order Manifest
  collect :order_manifest do
    argument :order_id, input(:order_id)
    argument :credit, result(:check_credit)
    argument :delivery, result(:deliver)

    transform fn inputs ->
      %{
        order_id: inputs.order_id,
        status: :delivered,
        credit: inputs.credit,
        delivery: inputs.delivery
      }
    end
  end

  return :order_manifest
end
