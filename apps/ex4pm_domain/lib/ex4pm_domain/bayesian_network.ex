defmodule Ex4pmDomain.BayesianNetwork do
  @moduledoc """
  Ash Resource representing a Bayesian Network with DAG topology and Conditional Probability Tables.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :nodes, :cpts, :metadata])
    end

    update :update do
      primary?(true)
      accept([:nodes, :cpts, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:nodes, {:array, :string}, allow_nil?: false, public?: true)
    attribute(:cpts, :map, default: %{}, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
