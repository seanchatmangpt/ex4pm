defmodule Ex4pmCore.Blueprints.LedgerTransfer do
  @moduledoc """
  Canonical Double-Entry Ledger Transfer Process Blueprint with Saga Reversal.
  Models: Validate Accounts -> Debit Source -> Credit Destination -> Reconcile Balance.
  """

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.{Activity, ObjectType, PartialOrder, Policy}

  def blueprint(opts \\ []) do
    process_id = Keyword.get(opts, :id, "double_entry_ledger_transfer")

    activities = %{
      "validate_accounts" => %Activity{
        id: "validate_accounts",
        label: "Validate Accounts",
        object_types: ["Transfer"],
        lifecycle_states: ["validated"]
      },
      "debit_source_account" => %Activity{
        id: "debit_source_account",
        label: "Debit Source Account",
        object_types: ["Transfer"],
        lifecycle_states: ["debited"]
      },
      "credit_destination_account" => %Activity{
        id: "credit_destination_account",
        label: "Credit Destination Account",
        object_types: ["Transfer"],
        lifecycle_states: ["credited"]
      },
      "reconcile_transfer_balance" => %Activity{
        id: "reconcile_transfer_balance",
        label: "Reconcile Transfer Balance",
        object_types: ["Transfer"],
        lifecycle_states: ["completed"]
      }
    }

    edges = [
      {"validate_accounts", "debit_source_account"},
      {"debit_source_account", "credit_destination_account"},
      {"credit_destination_account", "reconcile_transfer_balance"}
    ]

    partial_orders = %{
      "ledger_dag" => %PartialOrder{
        id: "ledger_dag",
        nodes: Map.keys(activities),
        edges: edges
      }
    }

    policies = %{
      "zero_sum_balance_invariant" => %Policy{
        id: "zero_sum_balance_invariant",
        type: :custom,
        target_activities: ["reconcile_transfer_balance"],
        target_objects: ["Transfer"],
        description: "Debit amount must exactly equal credit amount (zero sum balance)."
      }
    }

    objects = %{
      "Transfer" => %ObjectType{
        id: "Transfer",
        name: "Transfer",
        attributes: %{"amount" => %{type: "decimal"}, "currency" => %{type: "string"}}
      }
    }

    %ProcessIR{
      id: process_id,
      name: "Double-Entry Ledger Transfer",
      version: "1.0.0",
      activities: activities,
      objects: objects,
      partial_orders: partial_orders,
      policies: policies,
      root: "ledger_dag"
    }
  end
end
