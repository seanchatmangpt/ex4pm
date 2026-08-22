defmodule Ex4pm.Domain.Projector do
  @moduledoc "Explicit projection from canonical semantic/evidence objects into Ash resources."

  alias Ex4pm.Core.Hash

  alias Ex4pm.Domain.{
    Agent,
    AgentRun,
    ConformanceResult,
    Dataset,
    EngineCapability,
    Event,
    EventObject,
    Intervention,
    Object,
    ObjectObject,
    ProcessModel,
    ProcessVariant,
    ReceiptProjection,
    Refusal
  }

  alias Ex4pm.Engine.Result
  alias Ex4pm.EventLog
  alias Ex4pm.Evidence.Receipt
  alias Ex4pm.Refusal, as: CoreRefusal

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

  def event(%Ex4pm.Event{} = ev) do
    create(Event, %{
      event_id: ev.id,
      activity: ev.activity,
      lifecycle: Map.get(ev.attributes, "lifecycle", "stop"),
      timestamp: ev.timestamp,
      agent_id: Map.get(ev.attributes, "agent_id") || Map.get(ev.attributes, :agent_id),
      run_id: Map.get(ev.attributes, "run_id") || Map.get(ev.attributes, :run_id),
      tool: Map.get(ev.attributes, "tool") || Map.get(ev.attributes, :tool),
      authority_domain: Map.get(ev.attributes, "authority_domain", "OBSERVE"),
      standing: Map.get(ev.attributes, "standing", :alive),
      attributes: ev.attributes
    })
  end

  def object(%Ex4pm.ObjectRef{} = obj) do
    create(Object, %{
      object_id: obj.id,
      type: to_string(obj.type),
      attributes: obj.attributes
    })
  end

  def event_object(event_id, object_id, qualifier \\ "involved") do
    create(EventObject, %{
      event_id: to_string(event_id),
      object_id: to_string(object_id),
      qualifier: to_string(qualifier)
    })
  end

  def object_object(source_id, target_id, qualifier \\ "related") do
    create(ObjectObject, %{
      source_id: to_string(source_id),
      target_id: to_string(target_id),
      qualifier: to_string(qualifier)
    })
  end

  def agent(attrs) when is_map(attrs) do
    create(Agent, attrs)
  end

  def agent_run(attrs) when is_map(attrs) do
    create(AgentRun, attrs)
  end

  def variant(path, count, object_type \\ nil) do
    create(ProcessVariant, %{
      path: Enum.map(path, &to_string/1),
      count: count,
      object_type: if(object_type, do: to_string(object_type), else: nil)
    })
  end

  def conformance_result(attrs) when is_map(attrs) do
    create(ConformanceResult, attrs)
  end

  def refusal(%CoreRefusal{} = refusal) do
    create(Refusal, %{
      code: refusal.code,
      message: refusal.message,
      agent_id: Map.get(refusal.details, :agent_id) || Map.get(refusal.details, "agent_id"),
      run_id: Map.get(refusal.details, :run_id) || Map.get(refusal.details, "run_id"),
      standing: :refused,
      details: refusal.details
    })
  end

  def refusal(attrs) when is_map(attrs) do
    create(Refusal, attrs)
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

  def project_log(%EventLog{} = log) do
    with {:ok, _ds} <- dataset(log) do
      # Project objects
      Enum.each(log.objects, fn {_id, obj} -> object(obj) end)

      # Project events and E2O
      Enum.each(log.events, fn ev ->
        event(ev)

        Enum.each(ev.relationships, fn rel ->
          event_object(ev.id, rel.object_id, rel.qualifier)
        end)
      end)

      # Project O2O
      Enum.each(log.object_relationships, fn rel ->
        object_object(rel.source_id, rel.target_id, rel.qualifier)
      end)

      {:ok, :projected}
    end
  end

  defp create(resource, attrs) do
    resource
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(domain: Ex4pm.Domain)
  end
end
