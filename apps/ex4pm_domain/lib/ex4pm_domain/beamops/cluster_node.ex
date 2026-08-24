# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmDomain.BEAMOps.ClusterNode do
  @moduledoc """
  Ash Resource representing an active BEAM VM participant in a distributed Erlang cluster.
  Maps to `beamops:ClusterNode` in public ontology.
  """
  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
    table(:beamops_cluster_nodes)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:id, :node_name, :ip_address, :port, :status, :node_type, :heartbeat_at, :metadata])
    end

    update :update do
      primary?(true)
      accept([:status, :heartbeat_at, :metadata])
    end

    update :heartbeat do
      accept([:heartbeat_at, :status])
    end
  end

  attributes do
    attribute(:id, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:node_name, :string, allow_nil?: false, public?: true)
    attribute(:ip_address, :string, default: "127.0.0.1", public?: true)
    attribute(:port, :integer, default: 4369, public?: true)
    attribute(:status, :atom, default: :healthy, public?: true)
    attribute(:node_type, :atom, default: :worker, public?: true)
    attribute(:heartbeat_at, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
    attribute(:ontology_class, :string, default: "beamops:ClusterNode", public?: true)
  end
end
