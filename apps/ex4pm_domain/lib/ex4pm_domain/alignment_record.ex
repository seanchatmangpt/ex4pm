defmodule Ex4pmDomain.AlignmentRecord do
  @moduledoc """
  Ash Resource storing A* Cost-Based Optimal Trace Alignment results.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :case_id,
        :trace_length,
        :total_cost,
        :fitness,
        :sync_moves,
        :log_moves,
        :model_moves,
        :metadata
      ])
    end

    update :update do
      primary?(true)
      accept([:total_cost, :fitness, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:case_id, :string, allow_nil?: false, public?: true)
    attribute(:trace_length, :integer, default: 0, public?: true)
    attribute(:total_cost, :float, default: 0.0, public?: true)
    attribute(:fitness, :float, default: 1.0, public?: true)
    attribute(:sync_moves, :integer, default: 0, public?: true)
    attribute(:log_moves, :integer, default: 0, public?: true)
    attribute(:model_moves, :integer, default: 0, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_case, [:case_id], pre_check_with: Ex4pmDomain)
  end
end
