defmodule Ex4pmCore.Blueprints.EnterprisePlatformNormative do
  @moduledoc """
  Prescriptive A-Priori Normative Process Model for XaaS Enterprise Platform.

  Defines strict ordering, mandatory authorization gates, and Separation of Duties
  policies across Operations, Accounts, Billing, Governance, and Ledger domains.
  """

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.{Activity, PartialOrder, Policy}

  def blueprint do
    activities =
      %{
        "capability_liveness_receipt.ingest" => %Activity{
          id: "capability_liveness_receipt.ingest",
          label: "Ingest Capability Receipt",
          lifecycle_states: ["create", "complete"]
        },
        "capability_liveness_receipt.read" => %Activity{
          id: "capability_liveness_receipt.read",
          label: "Read Capability Receipt",
          lifecycle_states: ["read"]
        },
        "capability_liveness_receipt.destroy" => %Activity{
          id: "capability_liveness_receipt.destroy",
          label: "Purge Capability Receipt",
          lifecycle_states: ["destroy"]
        },
        "approval_pricing_override.create" => %Activity{
          id: "approval_pricing_override.create",
          label: "Create Pricing Override",
          lifecycle_states: ["create"]
        },
        "approval_pricing_override.read" => %Activity{
          id: "approval_pricing_override.read",
          label: "Audit Pricing Override",
          lifecycle_states: ["read"]
        }
      }

    edges = [
      {"capability_liveness_receipt.ingest", "capability_liveness_receipt.read"},
      {"approval_pricing_override.create", "approval_pricing_override.read"}
    ]

    policies = [
      %Policy{
        id: "pol_sod_pricing",
        type: :sod,
        target_activities: ["approval_pricing_override.create", "approval_pricing_override.read"],
        description: "Separation of duties between pricing override request and audit approval",
        rules: %{enforcement: :strict}
      }
    ]

    %ProcessIR{
      id: "xaas_enterprise_platform_normative",
      name: "XaaS Enterprise Platform Prescriptive Normative Model",
      version: "2.0.0",
      activities: activities,
      partial_orders: %{
        "normative_dag" => %PartialOrder{
          id: "normative_dag",
          nodes: Map.keys(activities),
          edges: edges
        }
      },
      policies: policies,
      root: "normative_dag"
    }
  end
end
