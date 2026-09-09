defmodule MicroBeam4pm.OcelEvent do
  @moduledoc """
  Real Ash resource + AshJsonApi exposure standing in for beam4pm's real,
  already-existing `BeamPM.Ash.Resources.OcelEvent` -- same shape ex4pm's
  own `Ex4pmDomain.Event` uses (`Ash.DataLayer.Ets`), so
  `Ex4pm.Engine.Beam4pm`'s Chicago-style tests exercise the REAL
  AshJsonApi wire format (route shape, JSON:API response envelope)
  instead of a hand-guessed fake router. Test-only
  (`test/support`, `elixirc_paths(:test)`).
  """
  use Ash.Resource,
    domain: MicroBeam4pm.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "ocel_event"

    routes do
      base("/ocel_event")
      index(:read)
      get(:read)
      post(:create)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:activity, :timestamp])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:activity, :string, allow_nil?: false, public?: true)
    attribute(:timestamp, :string, public?: true)
  end
end

defmodule MicroBeam4pm.ConformanceResult do
  @moduledoc """
  Real Ash resource + AshJsonApi exposure standing in for beam4pm's real,
  already-existing `BeamPM.Ash.Resources.ConformanceResult`. See
  `MicroBeam4pm.OcelEvent`'s moduledoc for the full rationale.
  """
  use Ash.Resource,
    domain: MicroBeam4pm.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "conformance_result"

    routes do
      base("/conformance_result")
      index(:read)
      get(:read)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:fitness])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:fitness, :float, default: 1.0, public?: true)
  end
end

defmodule MicroBeam4pm.Domain do
  @moduledoc """
  Real Ash.Domain with AshJsonApi.Domain -- the same extension pairing
  beam4pm's own real `BeamPM.Ash.Domain` would need for its planned
  json_api exposure (docs/BEAM4PM-OPENAPI-GGEN-IGNITER-PLAN.md).
  """
  use Ash.Domain, extensions: [AshJsonApi.Domain], validate_config_inclusion?: false

  resources do
    resource(MicroBeam4pm.OcelEvent)
    resource(MicroBeam4pm.ConformanceResult)
  end
end

defmodule MicroBeam4pm.Router do
  @moduledoc """
  Real AshJsonApi.Router, including a real `/openapi.json` endpoint --
  proves the same real library beam4pm's future generation target
  (`docs/BEAM4PM-OPENAPI-GGEN-IGNITER-PLAN.md`) actually produces both a
  JSON:API surface and an OpenAPI document from one domain declaration.
  """
  use AshJsonApi.Router,
    domains: [MicroBeam4pm.Domain],
    open_api: "/openapi.json"
end
