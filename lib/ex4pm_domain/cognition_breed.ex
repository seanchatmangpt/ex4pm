defmodule Ex4pmDomain.CognitionBreed do
  @moduledoc """
  Ash Resource representing a cataloged Old-AI Cognition Breed (60+ breeds).
  Encompasses probabilistic graphs, logic solvers, planners, temporal calculi, and cognitive architectures.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :category, :formalism, :doctrine, :complexity, :parameters, :metadata])
    end

    update :update do
      primary?(true)
      accept([:parameters, :complexity, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:category, :atom, allow_nil?: false, public?: true)
    attribute(:formalism, :string, public?: true)

    attribute(:doctrine, :string,
      default: "Old AI is the factory. LLMs are the brochure.",
      public?: true
    )

    attribute(:complexity, :string, default: "polynomial", public?: true)
    attribute(:parameters, :map, default: %{}, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
