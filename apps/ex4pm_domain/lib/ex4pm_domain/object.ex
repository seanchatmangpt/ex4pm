defmodule Ex4pmDomain.Object do
  @moduledoc """
  Ash Resource representing an OCEL 2.0 object.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:id, :type, :attributes])
    end

    update :update do
      primary?(true)
      accept([:type, :attributes])
    end
  end

  attributes do
    attribute(:id, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:type, :string, allow_nil?: false, public?: true)
    attribute(:attributes, :map, default: %{}, public?: true)
  end

  relationships do
    has_many(:event_objects, Ex4pmDomain.EventObject,
      destination_attribute: :object_id,
      public?: true
    )

    has_many(:source_relationships, Ex4pmDomain.ObjectObject,
      destination_attribute: :source_id,
      public?: true
    )

    has_many(:target_relationships, Ex4pmDomain.ObjectObject,
      destination_attribute: :target_id,
      public?: true
    )
  end
end
