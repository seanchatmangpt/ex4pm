defmodule Ex4pmDomain.BlackboardHypothesis do
  @moduledoc """
  Ash Resource representing a Hearsay-II blackboard hypothesis and knowledge source activation.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:level, :content, :confidence, :source, :support, :session_id, :metadata])
    end

    update :update do
      primary?(true)
      accept([:confidence, :support, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:level, :string, allow_nil?: false, public?: true)
    attribute(:content, :string, allow_nil?: false, public?: true)
    attribute(:confidence, :float, default: 1.0, public?: true)
    attribute(:source, :string, default: "knowledge_source", public?: true)
    attribute(:support, {:array, :string}, default: [], public?: true)
    attribute(:session_id, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end
