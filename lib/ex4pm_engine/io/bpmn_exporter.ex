# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.IO.BPMNExporter do
  @moduledoc """
  BPMN 2.0 XML Standard Exporter.
  Converts POWL 2.0 models into valid OMG BPMN 2.0 XML importable into Camunda Modeler and Signavio.
  """

  alias Ex4pmEngine.POWL.{ChoiceGraph, Node}

  @doc "Serializes a POWL 2.0 model into a standard BPMN 2.0 XML string."
  @spec to_xml(Node.t() | ChoiceGraph.t()) :: String.t()
  def to_xml(%Node{operator: :choice_graph, choice_graph: cg}) do
    to_xml(cg)
  end

  def to_xml(%ChoiceGraph{} = cg) do
    task_elements =
      Enum.map(cg.nodes, fn {id, node} ->
        label = Map.get(node, :label, id)

        """
            <bpmn:task id="task_#{id}" name="#{label}" />
        """
      end)
      |> Enum.join("\n")

    start_del = ChoiceGraph.start_delimiter()
    end_del = ChoiceGraph.end_delimiter()

    flow_elements =
      cg.edges
      |> Enum.with_index(1)
      |> Enum.map(fn {{src, dst}, idx} ->
        src_ref = if src == start_del, do: "start_event_1", else: "task_#{src}"
        dst_ref = if dst == end_del, do: "end_event_1", else: "task_#{dst}"

        """
            <bpmn:sequenceFlow id="flow_#{idx}" sourceRef="#{src_ref}" targetRef="#{dst_ref}" />
        """
      end)
      |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                      xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI"
                      xmlns:dc="http://www.omg.org/spec/DD/20100524/DC"
                      xmlns:di="http://www.omg.org/spec/DD/20100524/DI"
                      id="Definitions_POWL"
                      targetNamespace="http://bpmn.io/schema/bpmn">
      <bpmn:process id="Process_POWL_2_0" isExecutable="true">
        <bpmn:startEvent id="start_event_1" name="▷ Start" />
    #{task_elements}
        <bpmn:endEvent id="end_event_1" name="□ End" />
    #{flow_elements}
      </bpmn:process>
    </bpmn:definitions>
    """
  end

  def to_xml(other) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                      id="Definitions_POWL"
                      targetNamespace="http://bpmn.io/schema/bpmn">
      <bpmn:process id="Process_POWL_2_0" isExecutable="true">
        <bpmn:startEvent id="start_1" name="▷ Start" />
        <bpmn:task id="task_main" name="#{inspect(other)}" />
        <bpmn:endEvent id="end_1" name="□ End" />
        <bpmn:sequenceFlow id="f1" sourceRef="start_1" targetRef="task_main" />
        <bpmn:sequenceFlow id="f2" sourceRef="task_main" targetRef="end_1" />
      </bpmn:process>
    </bpmn:definitions>
    """
  end
end
