defmodule Ex4pmDomain.ParetoFrontier do
  @moduledoc """
  Ash Resource representing a multi-objective Pareto dominance ranking of candidate process models.
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
        :candidates_count,
        :frontier_size,
        :frontier_candidates,
        :objectives,
        :metadata
      ])
    end

    update :update do
      primary?(true)
      accept([:frontier_size, :frontier_candidates, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:candidates_count, :integer, default: 0, public?: true)
    attribute(:frontier_size, :integer, default: 0, public?: true)
    attribute(:frontier_candidates, {:array, :map}, default: [], public?: true)
    attribute(:objectives, {:array, :string}, default: ["fitness:max", "cost:min"], public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
