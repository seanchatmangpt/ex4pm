defmodule Ex4pmDomain.EventObject do
  @moduledoc """
  Ash Resource representing an Event-to-Object (E2O) relationship.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:event_id, :object_id, :qualifier])
    end

    update :update do
      primary?(true)
      accept([:event_id, :object_id, :qualifier])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:event_id, :string, allow_nil?: false, public?: true)
    attribute(:object_id, :string, allow_nil?: false, public?: true)
    attribute(:qualifier, :string, default: "involved", public?: true)
  end

  relationships do
    belongs_to(:event, Ex4pmDomain.Event,
      source_attribute: :event_id,
      define_attribute?: false,
      public?: true
    )

    belongs_to(:object, Ex4pmDomain.Object,
      source_attribute: :object_id,
      define_attribute?: false,
      public?: true
    )
  end
end
