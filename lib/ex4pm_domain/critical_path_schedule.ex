defmodule Ex4pmDomain.CriticalPathSchedule do
  @moduledoc """
  Ash Resource representing a Critical Path Method (CPM) Schedule for multi-agent DAG execution.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :total_duration_ms, :critical_path, :task_schedules, :metadata])
    end

    update :update do
      primary?(true)
      accept([:total_duration_ms, :critical_path, :task_schedules, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:total_duration_ms, :integer, default: 0, public?: true)
    attribute(:critical_path, {:array, :string}, default: [], public?: true)
    attribute(:task_schedules, :map, default: %{}, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
