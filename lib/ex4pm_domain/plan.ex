defmodule Ex4pmDomain.Plan do
  @moduledoc """
  Ash Resource representing a generated STRIPS or HTN execution plan.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:goal, :initial_state, :steps, :total_cost, :status, :metadata])
    end

    update :update do
      primary?(true)
      accept([:steps, :total_cost, :status, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:goal, {:array, :string}, allow_nil?: false, public?: true)
    attribute(:initial_state, {:array, :string}, default: [], public?: true)
    attribute(:steps, {:array, :string}, default: [], public?: true)
    attribute(:total_cost, :float, default: 0.0, public?: true)
    attribute(:status, :atom, default: :planned, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end
