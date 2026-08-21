defmodule Ex4pm.Domain.Projector do
  @moduledoc "Explicit projection from canonical semantic/evidence objects into Ash resources."

  alias Ex4pm.Core.Hash
  alias Ex4pm.Domain.{Dataset, EngineCapability, Intervention, ProcessModel, ReceiptProjection}
  alias Ex4pm.Engine.Result
  alias Ex4pm.EventLog
  alias Ex4pm.Evidence.Receipt

  def dataset(%EventLog{} = log) do
    create(Dataset, %{
      subject_hash: log.subject.hash,
      format: log.source_format,
      event_count: length(log.events),
      object_count: map_size(log.objects),
      standing: :alive,
      metadata: log.metadata
    })
  end

  def process_model(%Result{operation: :discover} = result) do
    create(ProcessModel, %{
      subject_hash: result.subject_hash,
      algorithm: result.algorithm,
      engine: result.engine,
      model_hash: Hash.digest(result.value),
      standing: result.standing,
      model: result.value,
      metadata: result.evidence
    })
  end

  def intervention(subject_hash, candidate) when is_map(candidate) do
    create(Intervention, %{
      subject_hash: subject_hash,
      kind: Map.get(candidate, :kind, :unknown),
      status: :constructed,
      payload: candidate
    })
  end

  def receipt(%Receipt{} = receipt) do
    create(ReceiptProjection, %{
      hash: receipt.hash,
      parent_hash: receipt.parent_hash,
      subject_hash: receipt.subject_hash,
      phase: receipt.phase,
      operation: inspect(receipt.operation),
      standing: receipt.standing,
      artifact_hash: receipt.artifact_hash,
      metadata: receipt.metadata
    })
  end

  def capability(%Ex4pm.Core.Capability{} = capability) do
    create(EngineCapability, %{
      engine: capability.id,
      operation: capability.constraints[:operation],
      standing: capability.standing,
      reason: capability.reason,
      evidence: capability.evidence
    })
  end

  defp create(resource, attrs) do
    resource
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(domain: Ex4pm.Domain)
  end
end
