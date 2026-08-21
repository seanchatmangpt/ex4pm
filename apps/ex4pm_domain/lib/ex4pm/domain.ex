defmodule Ex4pm.Domain do
  @moduledoc "Ash semantic/control-plane projection for ex4pm."

  use Ash.Domain

  resources do
    resource Ex4pm.Domain.Dataset
    resource Ex4pm.Domain.ProcessModel
    resource Ex4pm.Domain.Intervention
    resource Ex4pm.Domain.ReceiptProjection
    resource Ex4pm.Domain.EngineCapability
  end
end

defmodule Ex4pm.Domain.Dataset do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:subject_hash, :format, :event_count, :object_count, :standing, :metadata]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :subject_hash, :string, allow_nil?: false, public?: true
    attribute :format, :atom, allow_nil?: false, public?: true
    attribute :event_count, :integer, allow_nil?: false, public?: true
    attribute :object_count, :integer, allow_nil?: false, public?: true
    attribute :standing, :atom, allow_nil?: false, public?: true
    attribute :metadata, :map, default: %{}, public?: true
  end
end

defmodule Ex4pm.Domain.ProcessModel do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:subject_hash, :algorithm, :engine, :model_hash, :standing, :model, :metadata]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :subject_hash, :string, allow_nil?: false, public?: true
    attribute :algorithm, :atom, allow_nil?: false, public?: true
    attribute :engine, :atom, allow_nil?: false, public?: true
    attribute :model_hash, :string, allow_nil?: false, public?: true
    attribute :standing, :atom, allow_nil?: false, public?: true
    attribute :model, :map, allow_nil?: false, public?: true
    attribute :metadata, :map, default: %{}, public?: true
  end
end

defmodule Ex4pm.Domain.Intervention do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:subject_hash, :kind, :status, :authority_ref, :receipt_hash, :payload]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :subject_hash, :string, allow_nil?: false, public?: true
    attribute :kind, :atom, allow_nil?: false, public?: true
    attribute :status, :atom, allow_nil?: false, public?: true
    attribute :authority_ref, :string, public?: true
    attribute :receipt_hash, :string, public?: true
    attribute :payload, :map, default: %{}, public?: true
  end
end

defmodule Ex4pm.Domain.ReceiptProjection do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:hash, :parent_hash, :subject_hash, :phase, :operation, :standing, :artifact_hash, :metadata]
    end
  end

  attributes do
    attribute :hash, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :parent_hash, :string, public?: true
    attribute :subject_hash, :string, allow_nil?: false, public?: true
    attribute :phase, :atom, allow_nil?: false, public?: true
    attribute :operation, :string, allow_nil?: false, public?: true
    attribute :standing, :atom, public?: true
    attribute :artifact_hash, :string, public?: true
    attribute :metadata, :map, default: %{}, public?: true
  end
end

defmodule Ex4pm.Domain.EngineCapability do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:engine, :operation, :standing, :reason, :evidence]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :engine, :atom, allow_nil?: false, public?: true
    attribute :operation, :atom, allow_nil?: false, public?: true
    attribute :standing, :atom, allow_nil?: false, public?: true
    attribute :reason, :atom, public?: true
    attribute :evidence, :map, default: %{}, public?: true
  end
end
