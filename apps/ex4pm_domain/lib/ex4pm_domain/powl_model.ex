defmodule Ex4pmDomain.PowlModel do
  @moduledoc """
  Ash Resource storing sound-by-construction POWL 2.0 process trees.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  alias Wasm4pmCompat.AshTypes.Powl

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :name,
        :root_operator,
        :node_count,
        :sound_by_construction?,
        :powl_tree,
        :order_edges,
        :metadata
      ])
    end

    update :update do
      primary?(true)
      accept([:node_count, :powl_tree, :order_edges, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:root_operator, :atom, default: :sequence, public?: true)
    attribute(:node_count, :integer, default: 1, public?: true)
    attribute(:sound_by_construction?, :boolean, default: true, public?: true)
    attribute(:powl_tree, Powl.Powl, public?: true)
    attribute(:order_edges, {:array, Powl.OrderEdge}, default: [], public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
