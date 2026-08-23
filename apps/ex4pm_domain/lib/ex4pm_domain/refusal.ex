defmodule Ex4pmDomain.Refusal do
  @moduledoc """
  Ash Resource representing a typed rejection, validation failure, or security refusal.
  """

  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  alias Wasm4pmCompat.AshTypes.Admission

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :code,
        :reason,
        :agent_id,
        :run_id,
        :refusal_payload,
        :details,
        :subject_hash,
        :timestamp
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:code, :atom, allow_nil?: false, public?: true)
    attribute(:reason, :string, allow_nil?: false, public?: true)
    attribute(:agent_id, :string, public?: true)
    attribute(:run_id, :string, public?: true)
    attribute(:refusal_payload, Admission.Refusal, public?: true)
    attribute(:details, :map, default: %{}, public?: true)
    attribute(:subject_hash, :string, public?: true)
    attribute(:timestamp, :string, public?: true)
  end
end
