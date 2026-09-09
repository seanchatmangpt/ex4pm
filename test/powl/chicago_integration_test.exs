# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.POWL.ChicagoIntegrationTest do
  @moduledoc """
  Chicago-style Real-Boundary Integration Suite:
  Executes the full pipeline without mocks:
  Raw Event Stream -> InductiveMiner.mine/2 -> POWL Model -> WorkflowNet -> SoundnessProver -> Language -> BPMN & PNML Exporters.
  """
  use ExUnit.Case, async: true

  alias Ex4pmEngine.InductiveMiner
  alias Ex4pmEngine.IO.{BPMNExporter, EventLogParser, PNMLExporter}
  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.POWL.Language
  alias Ex4pmEngine.SoundnessProver

  test "full Chicago-style roundtrip across Order-to-Delivery industrial log" do
    csv_raw = """
    case_id,activity
    case_1,CheckCredit
    case_1,ExpressShip
    case_1,Deliver
    case_2,CheckCredit
    case_2,ExpressShip
    case_2,AddInsurance
    case_2,Deliver
    case_3,CheckCredit
    case_3,RegularShip
    case_3,Deliver
    """

    # 1. Parse CSV log
    assert {:ok, log} = EventLogParser.parse("order.csv", csv_raw)
    assert length(log) == 3

    # 2. Discover POWL 2.0 Choice Graph model
    assert {:ok, model} = InductiveMiner.mine(log)

    # 3. Prove language contains 100% of the input log traces
    model_lang = Language.evaluate(model)

    for trace <- log do
      assert trace in model_lang
    end

    # 4. Compile to Workflow Net and prove 1-safe soundness
    wf_net = POWL.to_workflow_net(model)
    report = SoundnessProver.verify_soundness(wf_net)

    assert report.sound? == true
    assert report.one_safe? == true
    assert report.option_to_complete? == true
    assert report.proper_completion? == true
    assert report.no_dead_transitions? == true

    # 5. Export to PNML XML and verify XML well-formedness
    pnml_xml = PNMLExporter.to_xml(wf_net)
    assert pnml_xml =~ "<pnml"
    assert pnml_xml =~ "<place id=\"p_start\""
    assert pnml_xml =~ "<place id=\"p_end\""
    assert pnml_xml =~ "<transition"

    # 6. Export to BPMN 2.0 XML and verify structure
    bpmn_xml = BPMNExporter.to_xml(model)
    assert bpmn_xml =~ "<bpmn:definitions"
    assert bpmn_xml =~ "<bpmn:startEvent id=\"start_event_1\""
    assert bpmn_xml =~ "<bpmn:task id=\"task_"
  end
end
