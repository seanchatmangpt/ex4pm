defmodule Ex4pmDomain.AgentRun do
  @moduledoc """
  Ash Resource representing a specific execution run of an agent.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :id,
        :agent_id,
        :sequence,
        :status,
        :standing,
        :current_activity,
        :started_at,
        :finished_at,
        :batch_count,
        :event_count,
        :metadata
      ])
    end

    update :update do
      primary?(true)

      accept([
        :sequence,
        :status,
        :standing,
        :current_activity,
        :finished_at,
        :batch_count,
        :event_count,
        :metadata
      ])
    end
  end

  attributes do
    attribute(:id, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:agent_id, :string, allow_nil?: false, public?: true)
    attribute(:sequence, :integer, default: 0, public?: true)
    attribute(:status, :atom, default: :running, public?: true)
    attribute(:standing, :atom, default: :alive, public?: true)
    attribute(:current_activity, :string, public?: true)
    attribute(:started_at, :string, public?: true)
    attribute(:finished_at, :string, public?: true)
    attribute(:batch_count, :integer, default: 0, public?: true)
    attribute(:event_count, :integer, default: 0, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  relationships do
    belongs_to(:agent, Ex4pmDomain.Agent,
      source_attribute: :agent_id,
      define_attribute?: false,
      public?: true
    )

    has_many(:events, Ex4pmDomain.Event, destination_attribute: :run_id, public?: true)
    has_many(:receipts, Ex4pmDomain.Receipt, destination_attribute: :run_id, public?: true)
  end
end
