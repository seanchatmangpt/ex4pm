defmodule Ex4pmDomain.CognitionSession do
  @moduledoc """
  Ash Resource representing a state-carrying compound reasoning session.
  Maintains working memory, active goals, intermediate proofs, and execution receipts.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :agent_id,
        :run_id,
        :status,
        :working_memory,
        :goals,
        :step_count,
        :receipt_hash,
        :metadata
      ])
    end

    update :update do
      primary?(true)
      accept([:status, :working_memory, :goals, :step_count, :receipt_hash, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:agent_id, :string, allow_nil?: false, public?: true)
    attribute(:run_id, :string, public?: true)
    attribute(:status, :atom, default: :active, public?: true)
    attribute(:working_memory, :map, default: %{}, public?: true)
    attribute(:goals, {:array, :string}, default: [], public?: true)
    attribute(:step_count, :integer, default: 0, public?: true)
    attribute(:receipt_hash, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end
