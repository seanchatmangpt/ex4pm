# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmDomain.BEAMOps.MetricProbe do
  @moduledoc """
  Ash Resource representing a PromEx telemetry metric probe and observation sample.
  Maps to `beamops:MetricProbe` in public ontology.
  """
  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
    table(:beamops_metric_probes)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:id, :name, :category, :value, :labels, :sample_timestamp, :alert_state, :metadata])
    end

    update :update do
      primary?(true)
      accept([:value, :labels, :sample_timestamp, :alert_state, :metadata])
    end
  end

  attributes do
    attribute(:id, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:category, :atom, default: :beam, public?: true)
    attribute(:value, :float, allow_nil?: false, public?: true)
    attribute(:labels, :map, default: %{}, public?: true)
    attribute(:sample_timestamp, :string, public?: true)
    attribute(:alert_state, :atom, default: :ok, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
    attribute(:ontology_class, :string, default: "beamops:MetricProbe", public?: true)
  end
end
