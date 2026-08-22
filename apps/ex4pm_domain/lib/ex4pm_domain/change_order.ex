defmodule Ex4pmDomain.ChangeOrder do
  @moduledoc """
  Ash Resource modeling an Enterprise Change Order Lifecycle as a formal 1-Safe State Machine.

  Transitions:
  :draft -> :requested -> :approved -> :executed -> :verified
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :draft do
      primary?(true)
      accept([:summary, :risk_level, :requester_id])
      change(set_attribute(:state, :draft))
    end

    update :request do
      accept([])
      validate(attribute_equals(:state, :draft))
      change(set_attribute(:state, :requested))
    end

    update :approve do
      accept([:approver_id])
      validate(attribute_equals(:state, :requested))
      change(set_attribute(:state, :approved))
    end

    update :execute do
      accept([])
      validate(attribute_equals(:state, :approved))
      change(set_attribute(:state, :executed))
    end

    update :verify do
      accept([:verification_notes])
      validate(attribute_equals(:state, :executed))
      change(set_attribute(:state, :verified))
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:summary, :string, allow_nil?: false, public?: true)
    attribute(:risk_level, :atom, default: :low, public?: true)
    attribute(:state, :atom, default: :draft, public?: true)
    attribute(:requester_id, :string, public?: true)
    attribute(:approver_id, :string, public?: true)
    attribute(:verification_notes, :string, public?: true)
  end

  @doc "Compiles the ChangeOrder state machine into a formal Workflow Net specification."
  def to_workflow_net do
    %{
      places: ["p_draft", "p_requested", "p_approved", "p_executed", "p_verified"],
      transitions: %{
        request: %{inputs: ["p_draft"], outputs: ["p_requested"], label: "request"},
        approve: %{inputs: ["p_requested"], outputs: ["p_approved"], label: "approve"},
        execute: %{inputs: ["p_approved"], outputs: ["p_executed"], label: "execute"},
        verify: %{inputs: ["p_executed"], outputs: ["p_verified"], label: "verify"}
      },
      initial_marking: ["p_draft"],
      final_marking: ["p_verified"]
    }
  end
end
