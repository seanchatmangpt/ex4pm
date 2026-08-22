defmodule Ex4pmDomain.PrologKb do
  @moduledoc """
  Ash Resource representing a Prolog Knowledge Base with Horn clauses and query interface.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :clauses, :clause_count, :metadata])
    end

    update :update do
      primary?(true)
      accept([:clauses, :clause_count, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:clauses, {:array, :map}, default: [], public?: true)
    attribute(:clause_count, :integer, default: 0, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
