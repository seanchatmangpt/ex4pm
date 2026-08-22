defmodule Ex4pmDomain.ChoreographyContract do
  @moduledoc """
  Ash Resource storing multi-agent communicating choreography contracts.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :participating_agents, :channels_count, :sound?, :deadlock_free?, :metadata])
    end

    update :update do
      primary?(true)
      accept([:sound?, :deadlock_free?, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:participating_agents, {:array, :string}, default: [], public?: true)
    attribute(:channels_count, :integer, default: 0, public?: true)
    attribute(:sound?, :boolean, default: true, public?: true)
    attribute(:deadlock_free?, :boolean, default: true, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
