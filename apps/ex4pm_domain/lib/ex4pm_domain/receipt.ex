defmodule Ex4pmDomain.Receipt do
  @moduledoc """
  Ash Resource representing a cryptographic receipt in the control plane.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
    table(:ex4pm_domain_receipts)
  end

  alias Wasm4pmCompat.AshTypes.Receipt

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :hash,
        :parent_hash,
        :subject_hash,
        :phase,
        :operation,
        :authority_hash,
        :artifact_hash,
        :standing,
        :agent_id,
        :run_id,
        :envelope,
        :receipt_chain,
        :shape,
        :replay_hint,
        :started_at,
        :finished_at,
        :metadata
      ])
    end

    update :update do
      primary?(true)

      accept([
        :parent_hash,
        :phase,
        :operation,
        :authority_hash,
        :artifact_hash,
        :standing,
        :agent_id,
        :run_id,
        :envelope,
        :receipt_chain,
        :shape,
        :replay_hint,
        :finished_at,
        :metadata
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:hash, :string, allow_nil?: false, public?: true)
    attribute(:parent_hash, :string, public?: true)
    attribute(:subject_hash, :string, allow_nil?: false, public?: true)
    attribute(:phase, :atom, allow_nil?: false, public?: true)
    attribute(:operation, :string, allow_nil?: false, public?: true)
    attribute(:authority_hash, :string, public?: true)
    attribute(:artifact_hash, :string, public?: true)
    attribute(:standing, :atom, public?: true)
    attribute(:agent_id, :string, public?: true)
    attribute(:run_id, :string, public?: true)
    attribute(:envelope, Receipt.ReceiptEnvelope, public?: true)
    attribute(:receipt_chain, Receipt.ReceiptChain, public?: true)
    attribute(:shape, Receipt.ReceiptShape, public?: true)
    attribute(:replay_hint, Receipt.ReplayHint, public?: true)
    attribute(:started_at, :string, public?: true)
    attribute(:finished_at, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
  end

  relationships do
    belongs_to(:run, Ex4pmDomain.AgentRun,
      source_attribute: :run_id,
      define_attribute?: false,
      public?: true
    )
  end
end
