defmodule Ex4pmCore.Blueprints.GovernanceApproval do
  @moduledoc """
  Canonical Two-Person Rule Governance Approval Process Blueprint.
  Models: Submit Change -> First Review -> Second Review -> Deploy -> Verify.
  """

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.{Activity, ObjectType, PartialOrder, Policy}

  def blueprint(opts \\ []) do
    process_id = Keyword.get(opts, :id, "governance_two_person_approval")

    activities = %{
      "submit_change" => %Activity{
        id: "submit_change",
        label: "Submit Change",
        object_types: ["ChangeRequest"],
        lifecycle_states: ["submitted"]
      },
      "first_review" => %Activity{
        id: "first_review",
        label: "First Review",
        object_types: ["ChangeRequest"],
        lifecycle_states: ["first_approved"]
      },
      "second_review" => %Activity{
        id: "second_review",
        label: "Second Review",
        object_types: ["ChangeRequest"],
        lifecycle_states: ["second_approved"]
      },
      "deploy_change" => %Activity{
        id: "deploy_change",
        label: "Deploy Change",
        object_types: ["ChangeRequest"],
        lifecycle_states: ["deployed"]
      },
      "verify_production" => %Activity{
        id: "verify_production",
        label: "Verify Production",
        object_types: ["ChangeRequest"],
        lifecycle_states: ["verified"]
      }
    }

    edges = [
      {"submit_change", "first_review"},
      {"first_review", "second_review"},
      {"second_review", "deploy_change"},
      {"deploy_change", "verify_production"}
    ]

    partial_orders = %{
      "approval_dag" => %PartialOrder{
        id: "approval_dag",
        nodes: Map.keys(activities),
        edges: edges
      }
    }

    policies = %{
      "sod_two_person_rule" => %Policy{
        id: "sod_two_person_rule",
        type: :sod,
        target_activities: ["first_review", "second_review"],
        target_objects: ["ChangeRequest"],
        description: "First and Second reviewers must be distinct actors."
      },
      "sod_submit_deploy" => %Policy{
        id: "sod_submit_deploy",
        type: :sod,
        target_activities: ["submit_change", "deploy_change"],
        target_objects: ["ChangeRequest"],
        description: "Submitter cannot independently deploy change."
      }
    }

    objects = %{
      "ChangeRequest" => %ObjectType{
        id: "ChangeRequest",
        name: "ChangeRequest",
        attributes: %{"change_type" => %{type: "string"}, "risk_level" => %{type: "string"}}
      }
    }

    %ProcessIR{
      id: process_id,
      name: "Two-Person Rule Governance Approval",
      version: "1.0.0",
      activities: activities,
      objects: objects,
      partial_orders: partial_orders,
      policies: policies,
      root: "approval_dag"
    }
  end
end
