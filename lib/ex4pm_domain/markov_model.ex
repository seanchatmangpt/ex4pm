defmodule Ex4pmDomain.MarkovModel do
  @moduledoc """
  Ash Resource representing a Markov Process State Transition Model.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :states, :state_count, :transition_matrix, :metadata])
    end

    update :update do
      primary?(true)
      accept([:state_count, :transition_matrix, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:states, {:array, :string}, default: [], public?: true)
    attribute(:state_count, :integer, default: 0, public?: true)
    attribute(:transition_matrix, :map, default: %{}, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
