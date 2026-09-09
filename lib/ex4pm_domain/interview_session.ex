defmodule Ex4pmDomain.InterviewSession do
  @moduledoc """
  Ash Resource representing an InterviewAssist active inquiry session.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:agent_id, :status, :questions, :responses, :ambiguity_score, :metadata])
    end

    update :update do
      primary?(true)
      accept([:status, :questions, :responses, :ambiguity_score, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:agent_id, :string, allow_nil?: false, public?: true)
    attribute(:status, :atom, default: :active, public?: true)
    attribute(:questions, {:array, :map}, default: [], public?: true)
    attribute(:responses, {:array, :map}, default: [], public?: true)
    attribute(:ambiguity_score, :float, default: 1.0, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end
