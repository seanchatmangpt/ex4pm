defmodule Ex4pmDomain.ConformanceResult do
  @moduledoc """
  Ash Resource representing an operational conformance verification result.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :subject_hash,
        :agent_id,
        :run_id,
        :fitness,
        :precision,
        :standing,
        :deviations,
        :conformance_vector,
        :evaluated_at,
        :metadata
      ])
    end

    update :update do
      primary?(true)

      accept([
        :fitness,
        :precision,
        :standing,
        :deviations,
        :conformance_vector,
        :evaluated_at,
        :metadata
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:subject_hash, :string, allow_nil?: false, public?: true)
    attribute(:agent_id, :string, public?: true)
    attribute(:run_id, :string, public?: true)
    attribute(:fitness, :float, default: 1.0, allow_nil?: false, public?: true)
    attribute(:precision, :float, default: 1.0, allow_nil?: false, public?: true)
    attribute(:standing, :atom, default: :alive, allow_nil?: false, public?: true)
    attribute(:deviations, {:array, :map}, default: [], public?: true)
    attribute(:conformance_vector, :map, default: %{}, public?: true)
    attribute(:evaluated_at, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end
