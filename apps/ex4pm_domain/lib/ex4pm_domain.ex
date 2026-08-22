defmodule Ex4pmDomain do
  @moduledoc """
  Ash Domain for the OCEL 2.0 Process Intelligence Control Plane.

  Exposes resources for agents, agent runs, events, objects, event-object (E2O) relations,
  object-object (O2O) relations, conformance verification results, refusals, cryptographic receipts,
  and autonomic capability liveness receipts.
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
    resource(Ex4pmDomain.CapabilityReceipt)

    # Cognition & AutoSystems Breeds (wasm4pm parity)
    resource(Ex4pmDomain.CognitionBreed)
    resource(Ex4pmDomain.CognitionSession)
    resource(Ex4pmDomain.BayesianNetwork)
    resource(Ex4pmDomain.PrologKb)
    resource(Ex4pmDomain.Plan)
    resource(Ex4pmDomain.BlackboardHypothesis)
    resource(Ex4pmDomain.TemporalModel)
    resource(Ex4pmDomain.ParetoFrontier)
    resource(Ex4pmDomain.InterviewSession)
    resource(Ex4pmDomain.AdversarialAudit)
    resource(Ex4pmDomain.SurvivalModel)
    resource(Ex4pmDomain.OcpqQuery)
    resource(Ex4pmDomain.CriticalPathSchedule)
    resource(Ex4pmDomain.MarkovModel)
    resource(Ex4pmDomain.CausalModel)
    resource(Ex4pmDomain.AlignmentRecord)
    resource(Ex4pmDomain.PowlModel)
    resource(Ex4pmDomain.LtlfConstraint)
    resource(Ex4pmDomain.ChoreographyContract)
    resource(Ex4pmDomain.ProcessIncident)
    resource(Ex4pmDomain.ChangeOrder)
  end
end
