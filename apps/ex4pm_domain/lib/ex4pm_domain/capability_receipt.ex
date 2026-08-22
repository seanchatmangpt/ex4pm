defmodule Ex4pmDomain.CapabilityReceipt do
  @moduledoc """
  Ash Resource representing an autonomic capability liveness receipt.

  Records verified capability claims, agent cryptographic signatures,
  execution exit codes, and autonomic regression detection state.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :capability,
        :subject,
        :status,
        :exit_code,
        :standing,
        :agent_id,
        :run_id,
        :digest,
        :verified_at,
        :metadata
      ])
    end

    update :update do
      primary?(true)

      accept([
        :status,
        :exit_code,
        :standing,
        :digest,
        :verified_at,
        :metadata
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:capability, :string, allow_nil?: false, public?: true)
    attribute(:subject, :string, allow_nil?: false, public?: true)
    attribute(:status, :atom, default: :alive, public?: true)
    attribute(:exit_code, :integer, default: 0, public?: true)
    attribute(:standing, :atom, default: :ALIVE, public?: true)
    attribute(:agent_id, :string, public?: true)
    attribute(:run_id, :string, public?: true)
    attribute(:digest, :string, public?: true)
    attribute(:verified_at, :utc_datetime_usec, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  identities do
    identity(:unique_capability_subject, [:capability, :subject], pre_check_with: Ex4pmDomain)
  end
end
