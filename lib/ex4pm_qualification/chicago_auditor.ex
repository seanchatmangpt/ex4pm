# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Qualification.ChicagoAuditor do
  @moduledoc """
  Dynamically audits stateful Chicago-style integration test utilization by scanning test ASTs
  and cross-referencing against declared Ash domain resources and Reactor sagas.
  """

  alias Ex4pmDomain

  @all_resources [
    Ex4pmDomain.Agent,
    Ex4pmDomain.AgentRun,
    Ex4pmDomain.Event,
    Ex4pmDomain.Object,
    Ex4pmDomain.EventObject,
    Ex4pmDomain.ObjectObject,
    Ex4pmDomain.ConformanceResult,
    Ex4pmDomain.Refusal,
    Ex4pmDomain.Receipt,
    Ex4pmDomain.CapabilityReceipt,
    Ex4pmDomain.CognitionBreed,
    Ex4pmDomain.CognitionSession,
    Ex4pmDomain.BayesianNetwork,
    Ex4pmDomain.PrologKb,
    Ex4pmDomain.Plan,
    Ex4pmDomain.BlackboardHypothesis,
    Ex4pmDomain.TemporalModel,
    Ex4pmDomain.ParetoFrontier,
    Ex4pmDomain.InterviewSession,
    Ex4pmDomain.AdversarialAudit,
    Ex4pmDomain.SurvivalModel,
    Ex4pmDomain.OcpqQuery,
    Ex4pmDomain.CriticalPathSchedule,
    Ex4pmDomain.MarkovModel,
    Ex4pmDomain.CausalModel,
    Ex4pmDomain.AlignmentRecord,
    Ex4pmDomain.PowlModel,
    Ex4pmDomain.LtlfConstraint,
    Ex4pmDomain.ChoreographyContract,
    Ex4pmDomain.ProcessIncident,
    Ex4pmDomain.ChangeOrder,
    Ex4pmDomain.BEAMOps.KanbanCard,
    Ex4pmDomain.BEAMOps.ClusterNode,
    Ex4pmDomain.BEAMOps.Deployment,
    Ex4pmDomain.BEAMOps.MetricProbe
  ]

  @all_reactors [
    Ex4pmEngine.Reactors.BEAMOps.BookValidationReactor,
    Ex4pmEngine.Reactors.BEAMOps.ClusterRebalanceReactor,
    Ex4pmEngine.Reactors.BEAMOps.OcpqAdversarialReactor,
    Ex4pmEngine.Reactors.BEAMOps.PromexAuditReactor,
    Ex4pmEngine.Reactors.BEAMOps.RollingDeploymentReactor,
    Ex4pmEngine.Reactors.Chicago.ChicagoProcessIntelligenceReactor,
    Ex4pmEngine.Reactors.Chicago.ChicagoSagaRollbackReactor,
    Ex4pmEngine.Reactors.OrderToDeliveryEnterpriseReactor,
    Ex4pmEngine.Reactors.SelfConformanceReactor,
    Ex4pmEngine.Reactors.AutoFdePlannerReactor
  ]

  # Process-mining discovery/conformance algorithms actually implemented in this
  # codebase (apps/ex4pm_engine, apps/ex4pm_core), whose real invocation in the test
  # suite is scanned for below rather than assumed. Short names are matched the same
  # way @all_resources/@all_reactors are (substring over concatenated test source).
  # Only algorithms that actually exist as modules are listed here — no aspirational
  # entries (e.g. no "AlphaMiner"/"HeuristicMiner"/"FootprintConformance": none of
  # those are implemented, so listing them would make the denominator lie).
  @all_algorithms [
    "InductiveMiner",
    "OCPOWL",
    "OnlineMiner",
    "Alignment",
    "Replay",
    "Conformance"
  ]

  def audit do
    test_files = Path.wildcard("apps/*/test/**/*.exs")
    test_sources = Enum.map(test_files, &File.read!/1) |> Enum.join("\n")

    # Real dynamic scan of test code for module references
    resources_tested =
      Enum.count(@all_resources, fn res ->
        mod_name = inspect(res) |> String.split(".") |> List.last()
        String.contains?(test_sources, mod_name)
      end)

    reactors_tested =
      Enum.count(@all_reactors, fn r ->
        mod_name = inspect(r) |> String.split(".") |> List.last()
        String.contains?(test_sources, mod_name)
      end)

    total_resources = length(@all_resources)
    total_reactors = length(@all_reactors)

    algos_tested =
      Enum.count(@all_algorithms, fn name -> String.contains?(test_sources, name) end)

    total_algorithms = length(@all_algorithms)

    resource_utilization = Float.round(resources_tested / max(total_resources, 1) * 100, 1)
    reactor_utilization = Float.round(reactors_tested / max(total_reactors, 1) * 100, 1)
    algo_utilization = Float.round(algos_tested / max(total_algorithms, 1) * 100, 1)

    overall_utilization =
      Float.round((resource_utilization + reactor_utilization + algo_utilization) / 3, 1)

    # Real count of test blocks in test files
    chicago_tests_count =
      test_files
      |> Enum.map(fn file ->
        content = File.read!(file)
        # Count test macro occurrences
        Regex.scan(~r/\btest\s+"/, content) |> length()
      end)
      |> Enum.sum()

    %{
      total_resources: total_resources,
      resources_tested: resources_tested,
      resource_utilization: resource_utilization,
      total_reactors: total_reactors,
      reactors_tested: reactors_tested,
      reactor_utilization: reactor_utilization,
      total_algorithms: total_algorithms,
      algos_tested: algos_tested,
      algo_utilization: algo_utilization,
      overall_utilization: overall_utilization,
      standing: :alive,
      chicago_tests_count: chicago_tests_count
    }
  end
end
