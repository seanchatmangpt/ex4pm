defmodule Ex4pmEvidence.CapabilityMesh do
  @moduledoc """
  Vision 2030 Decentralized Cryptographic Capability Mesh.

  Maintains a tamper-evident Merkle DAG of:
  - W3C EARL 1.0 test assertions
  - SOSA/QUDT telemetry metric observations
  - SPDX 3.0 provenance lineage graphs
  - Autonomic CapabilityReceipt records
  """

  alias Ex4pmEvidence.Engine, as: EvidenceEngine
  alias Ex4pmDomain.CapabilityReceipt

  @doc "Appends a new capability assertion to the Merkle DAG and returns the updated chain root."
  def record_capability(agent_id, capability_name, outcome, opts \\ []) do
    info = Keyword.get(opts, :info, "Capability #{capability_name} verified by #{agent_id}")
    prev_root = Keyword.get(opts, :prev_root, "genesis_root_#{agent_id}")

    # 1. Generate W3C EARL 1.0 assertion
    {:ok, earl} =
      EvidenceEngine.build_earl_assertion(
        outcome: outcome,
        info: info
      )

    # 2. Compute Merkle Leaf Digest (SHA-256)
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    leaf_payload = "#{prev_root}|#{agent_id}|#{capability_name}|#{outcome}|#{timestamp}"
    leaf_hash = :crypto.hash(:sha256, leaf_payload) |> Base.encode16(case: :lower)

    # 3. Persist to CapabilityReceipt
    receipt_res =
      CapabilityReceipt
      |> Ash.Changeset.for_create(
        :create,
        %{
          capability: to_string(capability_name),
          subject:
            "https://mesh.vision2030.global/agents/#{agent_id}/capabilities/#{capability_name}",
          status: if(outcome == :passed, do: :alive, else: :blocked),
          exit_code: if(outcome == :passed, do: 0, else: 1),
          standing: if(outcome == :passed, do: :ALIVE, else: :BLOCKED),
          agent_id: to_string(agent_id),
          digest: leaf_hash,
          metadata: %{
            "earl_id" => earl.id,
            "earl_result_id" => earl.result_id,
            "prev_merkle_root" => prev_root,
            "timestamp" => timestamp
          }
        },
        domain: Ex4pmDomain
      )
      |> Ash.create()

    case receipt_res do
      {:ok, receipt} ->
        {:ok,
         %{
           merkle_root: leaf_hash,
           prev_root: prev_root,
           receipt: receipt,
           earl: earl,
           timestamp: timestamp
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
