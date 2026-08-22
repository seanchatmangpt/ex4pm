defmodule Ex4pmDomain do
  @moduledoc """
  Ash Domain for the OCEL 2.0 Process Intelligence Control Plane.

  Exposes resources for agents, agent runs, events, objects, event-object (E2O) relations,
  object-object (O2O) relations, conformance verification results, refusals, and cryptographic receipts.
  """

  use Ash.Domain

  resources do
    resource(Ex4pmDomain.Agent)
    resource(Ex4pmDomain.AgentRun)
    resource(Ex4pmDomain.Event)
    resource(Ex4pmDomain.Object)
    resource(Ex4pmDomain.EventObject)
    resource(Ex4pmDomain.ObjectObject)
    resource(Ex4pmDomain.ConformanceResult)
    resource(Ex4pmDomain.Refusal)
    resource(Ex4pmDomain.Receipt)
  end
end
