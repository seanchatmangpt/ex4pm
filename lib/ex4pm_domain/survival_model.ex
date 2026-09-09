defmodule Ex4pmDomain.SurvivalModel do
  @moduledoc """
  Ash Resource representing a process survival model with Kaplan-Meier curves and RUL prediction.
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
        :sample_size,
        :median_duration_ms,
        :min_duration_ms,
        :max_duration_ms,
        :metadata
      ])
    end

    update :update do
      primary?(true)
      accept([:sample_size, :median_duration_ms, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:sample_size, :integer, default: 0, public?: true)
    attribute(:median_duration_ms, :integer, default: 0, public?: true)
    attribute(:min_duration_ms, :integer, default: 0, public?: true)
    attribute(:max_duration_ms, :integer, default: 0, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
