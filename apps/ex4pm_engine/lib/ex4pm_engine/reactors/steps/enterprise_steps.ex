# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.Steps.EnterpriseSteps do
  @moduledoc """
  Dedicated, reusable Reactor step modules with full 3-arity run/3, compensate/4, and undo/3 callbacks.
  """

  defmodule CheckCredit do
    use Reactor.Step

    @impl true
    def run(%{order_id: id, amount: amt}, _context, _options) do
      if amt > 100_000 do
        {:error, :credit_limit_exceeded}
      else
        {:ok, %{order_id: id, credit_approved: true, amount: amt}}
      end
    end

    @impl true
    def compensate(reason, _args, _context, _options) do
      case reason do
        :network_timeout -> :retry
        _other -> :ok
      end
    end

    @impl true
    def undo(_credit_info, %{order_id: id}, _context, _options) do
      send(self(), {:step_undone, :check_credit, id})
      :ok
    end
  end

  defmodule ReserveInventory do
    use Reactor.Step

    @impl true
    def run(%{item: item, order_id: id}, _context, _options) do
      {:ok, %{reserved_item: item, order_id: id, status: :held}}
    end

    @impl true
    def compensate(_reason, _args, _context, _options), do: :ok

    @impl true
    def undo(_info, %{item: item, order_id: id}, _context, _options) do
      send(self(), {:step_undone, :reserve_inventory, item, id})
      :ok
    end
  end

  defmodule ExpressShip do
    use Reactor.Step

    @impl true
    def run(%{order_id: id}, _context, _options) do
      {:ok, %{order_id: id, tracking: "EXP-#{id}", status: :dispatched}}
    end

    @impl true
    def compensate(_reason, _args, _context, _options), do: :ok

    @impl true
    def undo(_info, %{order_id: id}, _context, _options) do
      send(self(), {:step_undone, :express_ship, id})
      :ok
    end
  end

  defmodule RegularShip do
    use Reactor.Step

    @impl true
    def run(%{order_id: id}, _context, _options) do
      {:ok, %{order_id: id, tracking: "REG-#{id}", status: :dispatched}}
    end

    @impl true
    def compensate(_reason, _args, _context, _options), do: :ok

    @impl true
    def undo(_info, %{order_id: id}, _context, _options) do
      send(self(), {:step_undone, :regular_ship, id})
      :ok
    end
  end

  defmodule FaultyTerminalDelivery do
    use Reactor.Step

    @impl true
    def run(%{trigger_fault?: true}, _context, _options) do
      {:error, :terminal_delivery_barrier_tripped}
    end

    def run(%{order_id: id}, _context, _options) do
      {:ok, %{order_id: id, delivered: true}}
    end

    @impl true
    def compensate(_reason, _args, _context, _options), do: :ok

    @impl true
    def undo(_info, _args, _context, _options), do: :ok
  end
end
