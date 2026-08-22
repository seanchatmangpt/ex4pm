defmodule Ex4pmDomain.LtlfConstraint do
  @moduledoc """
  Ash Resource storing Linear Temporal Logic over Finite Traces (LTLf) constraints.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  alias Wasm4pmCompat.AshTypes.Declare

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([
        :name,
        :formula_type,
        :template,
        :scope,
        :declare_constraint,
        :source_activity,
        :target_activity,
        :satisfied?,
        :metadata
      ])
    end

    update :update do
      primary?(true)
      accept([:template, :scope, :declare_constraint, :satisfied?, :metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:formula_type, :string, default: "response", public?: true)
    attribute(:template, Declare.DeclareTemplate, public?: true)
    attribute(:scope, Declare.DeclareScope, public?: true)
    attribute(:declare_constraint, Declare.DeclareConstraint, public?: true)
    attribute(:source_activity, :string, public?: true)
    attribute(:target_activity, :string, public?: true)
    attribute(:satisfied?, :boolean, default: true, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_name, [:name], pre_check_with: Ex4pmDomain)
  end
end
