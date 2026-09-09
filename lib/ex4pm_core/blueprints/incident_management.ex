defmodule Ex4pmCore.Blueprints.IncidentManagement do
  @moduledoc """
  Canonical Enterprise Incident Management Process Blueprint.
  Models: Detection -> Triaging -> Investigation -> Remediation -> Post-Mortem -> Closure.
  """

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.{Activity, ObjectType, PartialOrder, Policy}

  def blueprint(opts \\ []) do
    process_id = Keyword.get(opts, :id, "enterprise_incident_management")

    activities = %{
      "detect_incident" => %Activity{
        id: "detect_incident",
        label: "Detect Incident",
        object_types: ["Incident"],
        lifecycle_states: ["create"]
      },
      "triage_incident" => %Activity{
        id: "triage_incident",
        label: "Triage Incident",
        object_types: ["Incident"],
        lifecycle_states: ["triaged"]
      },
      "investigate_root_cause" => %Activity{
        id: "investigate_root_cause",
        label: "Investigate Root Cause",
        object_types: ["Incident"],
        lifecycle_states: ["investigating"]
      },
      "apply_remediation" => %Activity{
        id: "apply_remediation",
        label: "Apply Remediation",
        object_types: ["Incident"],
        lifecycle_states: ["remediated"]
      },
      "publish_postmortem" => %Activity{
        id: "publish_postmortem",
        label: "Publish Post-Mortem",
        object_types: ["Incident"],
        lifecycle_states: ["postmortem_published"]
      },
      "close_incident" => %Activity{
        id: "close_incident",
        label: "Close Incident",
        object_types: ["Incident"],
        lifecycle_states: ["closed"]
      }
    }

    edges = [
      {"detect_incident", "triage_incident"},
      {"triage_incident", "investigate_root_cause"},
      {"investigate_root_cause", "apply_remediation"},
      {"apply_remediation", "publish_postmortem"},
      {"publish_postmortem", "close_incident"}
    ]

    partial_orders = %{
      "incident_dag" => %PartialOrder{
        id: "incident_dag",
        nodes: Map.keys(activities),
        edges: edges
      }
    }

    policies = %{
      "p99_remediation_sla" => %Policy{
        id: "p99_remediation_sla",
        type: :sla,
        target_activities: ["apply_remediation"],
        target_objects: ["Incident"],
        rules: %{max_duration_seconds: 3600},
        description: "P99 Incident Remediation SLA is 1 hour."
      }
    }

    objects = %{
      "Incident" => %ObjectType{
        id: "Incident",
        name: "Incident",
        attributes: %{"severity" => %{type: "string"}, "status" => %{type: "string"}}
      }
    }

    %ProcessIR{
      id: process_id,
      name: "Enterprise Incident Management",
      version: "1.0.0",
      activities: activities,
      objects: objects,
      partial_orders: partial_orders,
      policies: policies,
      root: "incident_dag"
    }
  end
end
