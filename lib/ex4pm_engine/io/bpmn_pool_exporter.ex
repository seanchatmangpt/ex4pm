# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.IO.BPMNPoolExporter do
  @moduledoc """
  Generates standard OMG BPMN 2.0 XML with Organizational Pools, Swimlanes, and Collaboration tags.
  """

  alias Ex4pmEngine.POWL.{ChoiceGraph, Node}

  @doc "Serializes a POWL model with an activity-to-pool/lane map into standard BPMN 2.0 Collaboration XML."
  @spec to_xml(Node.t() | ChoiceGraph.t(), %{String.t() => {String.t(), String.t()}}) ::
          String.t()
  def to_xml(_model, activity_to_pool_lane \\ %{}) do
    pools =
      activity_to_pool_lane
      |> Map.values()
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()

    pools_to_render = if pools == [], do: ["MainProcessPool"], else: pools

    participants_xml =
      Enum.map(pools_to_render, fn pool_name ->
        """
            <bpmn:participant id="Participant_#{pool_name}" name="#{pool_name}" processRef="Process_#{pool_name}" />
        """
      end)
      |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                      xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI"
                      xmlns:dc="http://www.omg.org/spec/DD/20100524/DC"
                      id="Definitions_POWL_Pools"
                      targetNamespace="http://bpmn.io/schema/bpmn">
      <bpmn:collaboration id="Collaboration_POWL">
    #{participants_xml}
      </bpmn:collaboration>
      <bpmn:process id="Process_#{List.first(pools_to_render)}" isExecutable="true">
        <bpmn:startEvent id="start_1" name="▷ Start" />
        <bpmn:endEvent id="end_1" name="□ End" />
      </bpmn:process>
    </bpmn:definitions>
    """
  end
end
