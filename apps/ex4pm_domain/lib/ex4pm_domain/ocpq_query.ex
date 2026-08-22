defmodule Ex4pmDomain.OcpqQuery do
  @moduledoc """
  Ash Resource representing an OCPQ Object-Centric Query Tree and Structural Invariant check.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :name,
        :root_vars,
        :predicates,
        :child_bounds,
        :satisfied?,
        :violations_count,
        :metadata
      ])
    end

    update :update do
      primary?(true)
      accept([:satisfied?, :violations_count, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:root_vars, {:array, :map}, default: [], public?: true)
    attribute(:predicates, {:array, :map}, default: [], public?: true)
    attribute(:child_bounds, :map, default: %{}, public?: true)
    attribute(:satisfied?, :boolean, default: true, public?: true)
    attribute(:violations_count, :integer, default: 0, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
