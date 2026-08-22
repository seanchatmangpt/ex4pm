defmodule Ex4pmDomain.Manager do
  @moduledoc """
  High-level transactional management interface for the OCEL 2.0 Process Intelligence Control Plane.
  """

  alias Ex4pmDomain.{
    Agent,
    AgentRun,
    ConformanceResult,
    Event,
    EventObject,
    Object,
    ObjectObject,
    Receipt,
    Refusal
  }

  @doc "Records or updates an agent in the control plane."
  def upsert_agent(attrs) do
    agent_id = to_string(attrs[:id] || attrs["id"])

    case Ash.get(Agent, agent_id, domain: Ex4pmDomain) do
      {:ok, existing} ->
        existing
        |> Ash.Changeset.for_update(:update, attrs)
        |> Ash.update(domain: Ex4pmDomain)

      {:error, _} ->
        Agent
        |> Ash.Changeset.for_create(:create, Map.put(attrs, :id, agent_id))
        |> Ash.create(domain: Ex4pmDomain)
    end
  end

  @doc "Records or updates an agent run in the control plane."
  def upsert_run(attrs) do
    run_id = to_string(attrs[:id] || attrs["id"])

    case Ash.get(AgentRun, run_id, domain: Ex4pmDomain) do
      {:ok, existing} ->
        existing
        |> Ash.Changeset.for_update(:update, attrs)
        |> Ash.update(domain: Ex4pmDomain)

      {:error, _} ->
        AgentRun
        |> Ash.Changeset.for_create(:create, Map.put(attrs, :id, run_id))
        |> Ash.create(domain: Ex4pmDomain)
    end
  end

  @doc "Inserts an event record."
  def create_event(attrs) do
    Event
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(domain: Ex4pmDomain)
  end

  @doc "Inserts or updates an object."
  def upsert_object(attrs) do
    object_id = to_string(attrs[:id] || attrs["id"])

    case Ash.get(Object, object_id, domain: Ex4pmDomain) do
      {:ok, existing} ->
        existing
        |> Ash.Changeset.for_update(:update, attrs)
        |> Ash.update(domain: Ex4pmDomain)

      {:error, _} ->
        Object
        |> Ash.Changeset.for_create(:create, Map.put(attrs, :id, object_id))
        |> Ash.create(domain: Ex4pmDomain)
    end
  end

  @doc "Links an event to an object."
  def create_event_object(attrs) do
    EventObject
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(domain: Ex4pmDomain)
  end

  @doc "Links an object to an object."
  def create_object_object(attrs) do
    ObjectObject
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(domain: Ex4pmDomain)
  end

  @doc "Records a conformance result."
  def record_conformance(attrs) do
    ConformanceResult
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(domain: Ex4pmDomain)
  end

  @doc "Records a refusal."
  def record_refusal(attrs) do
    Refusal
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(domain: Ex4pmDomain)
  end

  @doc "Records a receipt."
  def record_receipt(attrs) do
    Receipt
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(domain: Ex4pmDomain)
  end

  @doc "Lists all registered agents."
  def list_agents do
    Ash.read(Agent, domain: Ex4pmDomain)
  end

  @doc "Lists recent events, optionally limited."
  def list_events(limit \\ 100) do
    case Ash.read(Event, domain: Ex4pmDomain) do
      {:ok, events} -> {:ok, Enum.take(events, limit)}
      error -> error
    end
  end
end
