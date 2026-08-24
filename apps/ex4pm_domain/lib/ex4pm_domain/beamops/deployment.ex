# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmDomain.BEAMOps.Deployment do
  @moduledoc """
  Ash Resource representing an OTP release deployment and rolling update lifecycle.
  Maps to `beamops:Deployment` in public ontology.
  """
  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
    table(:beamops_deployments)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :id,
        :version,
        :image_digest,
        :target_nodes,
        :status,
        :rollback_version,
        :health_probes_passed,
        :metadata
      ])
    end

    update :update do
      primary?(true)
      accept([:status, :health_probes_passed, :metadata])
    end

    update :rollback do
      accept([:status, :rollback_version, :metadata])
    end
  end

  attributes do
    attribute(:id, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:version, :string, allow_nil?: false, public?: true)
    attribute(:image_digest, :string, public?: true)
    attribute(:target_nodes, {:array, :string}, default: [], public?: true)
    attribute(:status, :atom, default: :pending, public?: true)
    attribute(:rollback_version, :string, public?: true)
    attribute(:health_probes_passed, :integer, default: 0, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
    attribute(:ontology_class, :string, default: "beamops:Deployment", public?: true)
  end
end
