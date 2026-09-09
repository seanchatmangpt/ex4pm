defmodule Ex4pmDomain.Agent do
  @moduledoc """
  Ash Resource representing an autonomous or supervised agent in the fleet.
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
        :name,
        :capabilities,
        :status,
        :standing,
        :current_activity,
        :last_seen_at,
        :metadata
      ])
    end

    update :update do
      primary?(true)

      accept([
        :name,
        :capabilities,
        :status,
        :standing,
        :current_activity,
        :last_seen_at,
        :metadata
      ])
    end
  end

  attributes do
    attribute(:id, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:name, :string, public?: true)
    attribute(:capabilities, {:array, :string}, default: [], public?: true)
    attribute(:status, :atom, default: :active, public?: true)
    attribute(:standing, :atom, default: :alive, public?: true)
    attribute(:current_activity, :string, public?: true)
    attribute(:last_seen_at, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  relationships do
    has_many(:runs, Ex4pmDomain.AgentRun, destination_attribute: :agent_id, public?: true)
    has_many(:events, Ex4pmDomain.Event, destination_attribute: :agent_id, public?: true)
  end
end
