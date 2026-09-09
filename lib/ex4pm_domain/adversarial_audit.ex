defmodule Ex4pmDomain.AdversarialAudit do
  @moduledoc """
  Ash Resource recording AutoSystems 8 False-Pass adversarial audits.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:target_id, :passed?, :violations_count, :violations, :audited_at, :metadata])
    end

    update :update do
      primary?(true)
      accept([:passed?, :violations_count, :violations, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:target_id, :string, allow_nil?: false, public?: true)
    attribute(:passed?, :boolean, default: true, public?: true)
    attribute(:violations_count, :integer, default: 0, public?: true)
    attribute(:violations, {:array, :string}, default: [], public?: true)
    attribute(:audited_at, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end
