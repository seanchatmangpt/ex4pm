defmodule Ex4pmDomain.TemporalModel do
  @moduledoc """
  Ash Resource representing Allen's 13 interval relations and LTL constraints over process traces.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :intervals, :relations, :ltl_formulas, :metadata])
    end

    update :update do
      primary?(true)
      accept([:relations, :ltl_formulas, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:intervals, :map, default: %{}, public?: true)
    attribute(:relations, {:array, :map}, default: [], public?: true)
    attribute(:ltl_formulas, {:array, :string}, default: [], public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
