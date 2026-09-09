defmodule Ex4pmDomain.ProcessIncident do
  @moduledoc """
  Ash Resource modeling an Incident Lifecycle as a formal 1-Safe State Machine.

  Transitions:
  :reported -> :triaged -> :in_progress -> :resolved -> :closed
                                ^            |
                                +-- (reopen) +
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Ex4pmDomain.Extensions.SoundStateMachine]

  actions do
    defaults([:read, :destroy])

    create :report do
      primary?(true)
      accept([:title, :severity, :assigned_team])
      change(set_attribute(:state, :reported))
    end

    update :triage do
      accept([:assigned_team])
      validate(attribute_equals(:state, :reported))
      change(set_attribute(:state, :triaged))
    end

    update :investigate do
      accept([])
      validate(attribute_in(:state, [:triaged, :resolved]))
      change(set_attribute(:state, :in_progress))
    end

    update :resolve do
      accept([:resolution_notes])
      validate(attribute_equals(:state, :in_progress))
      change(set_attribute(:state, :resolved))
    end

    update :close do
      accept([])
      validate(attribute_equals(:state, :resolved))
      change(set_attribute(:state, :closed))
    end
  end

  alias Wasm4pmCompat.AshTypes.Diagnostic

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:severity, Diagnostic.DiagnosticSeverity, default: :medium, public?: true)
    attribute(:diagnostic, Diagnostic.CompatDiagnostic, public?: true)
    attribute(:state, :atom, default: :reported, public?: true)
    attribute(:assigned_team, :string, public?: true)
    attribute(:resolution_notes, :string, public?: true)
  end

  @doc "Compiles the Incident state machine into a formal Workflow Net specification."
  def to_workflow_net do
    %{
      places: ["p_reported", "p_triaged", "p_in_progress", "p_resolved", "p_closed"],
      transitions: %{
        triage: %{inputs: ["p_reported"], outputs: ["p_triaged"], label: "triage"},
        investigate: %{inputs: ["p_triaged"], outputs: ["p_in_progress"], label: "investigate"},
        resolve: %{inputs: ["p_in_progress"], outputs: ["p_resolved"], label: "resolve"},
        close: %{inputs: ["p_resolved"], outputs: ["p_closed"], label: "close"},
        reopen: %{inputs: ["p_resolved"], outputs: ["p_in_progress"], label: "reopen"}
      },
      initial_marking: ["p_reported"],
      final_marking: ["p_closed"]
    }
  end
end
