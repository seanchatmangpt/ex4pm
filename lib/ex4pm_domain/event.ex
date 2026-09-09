defmodule Ex4pmDomain.Event do
  @moduledoc """
  Ash Resource representing an OCEL 2.0 observed event.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  alias Wasm4pmCompat.AshTypes.Ids
  alias Wasm4pmCompat.AshTypes.Ocel

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :id,
        :activity,
        :timestamp,
        :agent_id,
        :run_id,
        :sequence,
        :subject_hash,
        :event_id_num,
        :activity_id_num,
        :ocel_event,
        :attributes
      ])
    end

    update :update do
      primary?(true)

      accept([
        :activity,
        :timestamp,
        :agent_id,
        :run_id,
        :sequence,
        :subject_hash,
        :event_id_num,
        :activity_id_num,
        :ocel_event,
        :attributes
      ])
    end
  end

  attributes do
    attribute(:id, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:activity, :string, allow_nil?: false, public?: true)
    attribute(:timestamp, :string, allow_nil?: false, public?: true)
    attribute(:agent_id, :string, public?: true)
    attribute(:run_id, :string, public?: true)
    attribute(:sequence, :integer, public?: true)
    attribute(:subject_hash, :string, public?: true)
    attribute(:event_id_num, Ids.EventId, public?: true)
    attribute(:activity_id_num, Ids.ActivityId, public?: true)
    attribute(:ocel_event, Ocel.OcelEvent, public?: true)
    attribute(:attributes, :map, default: %{}, public?: true)
  end

  relationships do
    belongs_to(:agent, Ex4pmDomain.Agent,
      source_attribute: :agent_id,
      define_attribute?: false,
      public?: true
    )

    belongs_to(:run, Ex4pmDomain.AgentRun,
      source_attribute: :run_id,
      define_attribute?: false,
      public?: true
    )

    has_many(:event_objects, Ex4pmDomain.EventObject,
      destination_attribute: :event_id,
      public?: true
    )
  end
end
