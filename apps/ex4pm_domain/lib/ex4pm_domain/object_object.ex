defmodule Ex4pmDomain.ObjectObject do
  @moduledoc """
  Ash Resource representing an Object-to-Object (O2O) relationship.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:source_id, :target_id, :qualifier])
    end

    update :update do
      primary?(true)
      accept([:source_id, :target_id, :qualifier])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:source_id, :string, allow_nil?: false, public?: true)
    attribute(:target_id, :string, allow_nil?: false, public?: true)
    attribute(:qualifier, :string, default: "related", public?: true)
  end

  relationships do
    belongs_to(:source, Ex4pmDomain.Object,
      source_attribute: :source_id,
      define_attribute?: false,
      public?: true
    )

    belongs_to(:target, Ex4pmDomain.Object,
      source_attribute: :target_id,
      define_attribute?: false,
      public?: true
    )
  end
end
