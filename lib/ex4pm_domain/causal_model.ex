defmodule Ex4pmDomain.CausalModel do
  @moduledoc """
  Ash Resource representing an inferred Causal Dependency Model over activity traces.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :activities, :edge_count, :strong_causal_edges, :metadata])
    end

    update :update do
      primary?(true)
      accept([:edge_count, :strong_causal_edges, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:activities, {:array, :string}, default: [], public?: true)
    attribute(:edge_count, :integer, default: 0, public?: true)
    attribute(:strong_causal_edges, :map, default: %{}, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
