defmodule Ex4pm.Domain do
  @moduledoc "Ash semantic/control-plane projection for ex4pm."

  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Ex4pm.Domain.Agent)
    resource(Ex4pm.Domain.AgentRun)
    resource(Ex4pm.Domain.Event)
    resource(Ex4pm.Domain.Object)
    resource(Ex4pm.Domain.EventObject)
    resource(Ex4pm.Domain.ObjectObject)
    resource(Ex4pm.Domain.ProcessVariant)
    resource(Ex4pm.Domain.ConformanceResult)
    resource(Ex4pm.Domain.Refusal)
    resource(Ex4pm.Domain.Dataset)
    resource(Ex4pm.Domain.ProcessModel)
    resource(Ex4pm.Domain.Intervention)
    resource(Ex4pm.Domain.ReceiptProjection)
    resource(Ex4pm.Domain.EngineCapability)
  end
end

defmodule Ex4pm.Domain.Agent do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:agent_id, :runtime, :authority_domains, :standing, :metadata])
    end

    update :update_status do
      accept([:standing, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:agent_id, :string, allow_nil?: false, public?: true)
    attribute(:runtime, :string, public?: true)

    attribute(:authority_domains, {:array, :string},
      default: ["OBSERVE", "CONSTRUCT"],
      public?: true
    )

    attribute(:standing, :atom, default: :alive, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.AgentRun do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :run_id,
        :agent_id,
        :repository,
        :status,
        :fitness,
        :started_at,
        :finished_at,
        :metadata
      ])
    end

    update :complete do
      accept([:status, :fitness, :finished_at, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:run_id, :string, allow_nil?: false, public?: true)
    attribute(:agent_id, :string, allow_nil?: false, public?: true)
    attribute(:repository, :string, public?: true)
    attribute(:status, :atom, default: :running, public?: true)
    attribute(:fitness, :float, default: 1.0, public?: true)
    attribute(:started_at, :string, public?: true)
    attribute(:finished_at, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.Event do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :event_id,
        :activity,
        :lifecycle,
        :timestamp,
        :agent_id,
        :run_id,
        :tool,
        :authority_domain,
        :standing,
        :attributes
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:event_id, :string, allow_nil?: false, public?: true)
    attribute(:activity, :string, allow_nil?: false, public?: true)
    attribute(:lifecycle, :string, default: "stop", public?: true)
    attribute(:timestamp, :string, allow_nil?: false, public?: true)
    attribute(:agent_id, :string, public?: true)
    attribute(:run_id, :string, public?: true)
    attribute(:tool, :string, public?: true)
    attribute(:authority_domain, :string, default: "OBSERVE", public?: true)
    attribute(:standing, :atom, default: :alive, public?: true)
    attribute(:attributes, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.Object do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:object_id, :type, :attributes])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:object_id, :string, allow_nil?: false, public?: true)
    attribute(:type, :string, allow_nil?: false, public?: true)
    attribute(:attributes, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.EventObject do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
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
end

defmodule Ex4pm.Domain.ObjectObject do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
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
end

defmodule Ex4pm.Domain.ProcessVariant do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:path, :count, :object_type, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:path, {:array, :string}, allow_nil?: false, public?: true)
    attribute(:count, :integer, default: 1, public?: true)
    attribute(:object_type, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.ConformanceResult do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :subject_hash,
        :fitness,
        :observed_edge_count,
        :deviation_count,
        :deviations,
        :metadata
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:subject_hash, :string, allow_nil?: false, public?: true)
    attribute(:fitness, :float, allow_nil?: false, public?: true)
    attribute(:observed_edge_count, :integer, default: 0, public?: true)
    attribute(:deviation_count, :integer, default: 0, public?: true)
    attribute(:deviations, :map, default: %{}, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.Refusal do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:code, :message, :agent_id, :run_id, :standing, :details])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:code, :atom, allow_nil?: false, public?: true)
    attribute(:message, :string, allow_nil?: false, public?: true)
    attribute(:agent_id, :string, public?: true)
    attribute(:run_id, :string, public?: true)
    attribute(:standing, :atom, default: :refused, public?: true)
    attribute(:details, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.Dataset do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:subject_hash, :format, :event_count, :object_count, :standing, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:subject_hash, :string, allow_nil?: false, public?: true)
    attribute(:format, :atom, allow_nil?: false, public?: true)
    attribute(:event_count, :integer, allow_nil?: false, public?: true)
    attribute(:object_count, :integer, allow_nil?: false, public?: true)
    attribute(:standing, :atom, allow_nil?: false, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.ProcessModel do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:subject_hash, :algorithm, :engine, :model_hash, :standing, :model, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:subject_hash, :string, allow_nil?: false, public?: true)
    attribute(:algorithm, :atom, allow_nil?: false, public?: true)
    attribute(:engine, :atom, allow_nil?: false, public?: true)
    attribute(:model_hash, :string, allow_nil?: false, public?: true)
    attribute(:standing, :atom, allow_nil?: false, public?: true)
    attribute(:model, :map, allow_nil?: false, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  calculations do
    calculate(:topology, :map, Ex4pm.Domain.ProcessGraphProjector)
  end
end

defmodule Ex4pm.Domain.Intervention do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:subject_hash, :kind, :status, :authority_ref, :receipt_hash, :payload])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:subject_hash, :string, allow_nil?: false, public?: true)
    attribute(:kind, :atom, allow_nil?: false, public?: true)
    attribute(:status, :atom, allow_nil?: false, public?: true)
    attribute(:authority_ref, :string, public?: true)
    attribute(:receipt_hash, :string, public?: true)
    attribute(:payload, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.ReceiptProjection do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :hash,
        :parent_hash,
        :subject_hash,
        :phase,
        :operation,
        :standing,
        :artifact_hash,
        :metadata
      ])
    end
  end

  attributes do
    attribute(:hash, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:parent_hash, :string, public?: true)
    attribute(:subject_hash, :string, allow_nil?: false, public?: true)
    attribute(:phase, :atom, allow_nil?: false, public?: true)
    attribute(:operation, :string, allow_nil?: false, public?: true)
    attribute(:standing, :atom, public?: true)
    attribute(:artifact_hash, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end
end

defmodule Ex4pm.Domain.EngineCapability do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:engine, :operation, :standing, :reason, :evidence])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:engine, :atom, allow_nil?: false, public?: true)
    attribute(:operation, :atom, allow_nil?: false, public?: true)
    attribute(:standing, :atom, allow_nil?: false, public?: true)
    attribute(:reason, :atom, public?: true)
    attribute(:evidence, :map, default: %{}, public?: true)
  end
end
