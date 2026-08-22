# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.IO.PNMLExporter do
  @moduledoc """
  ISO/IEC 15909-Compliant Petri Net Markup Language (PNML) Exporter.
  Produces valid `<pnml>` XML interchange files importable directly into ProM, WoPeD, and PM4Py.
  """

  alias Ex4pmEngine.WorkflowNet

  @doc "Serializes a Workflow Net into a standard PNML XML string."
  @spec to_xml(WorkflowNet.t()) :: String.t()
  def to_xml(%WorkflowNet{} = net) do
    places_xml =
      Enum.map(net.places, fn {p_id, _p_struct} ->
        """
            <place id="#{p_id}">
              <name><text>#{p_id}</text></name>
              #{if p_id == net.source_place, do: "<initialMarking><text>1</text></initialMarking>", else: ""}
            </place>
        """
      end)
      |> Enum.join("\n")

    transitions_xml =
      Enum.map(net.transitions, fn {t_id, t_struct} ->
        """
            <transition id="#{t_id}">
              <name><text>#{t_struct.label || t_id}</text></name>
            </transition>
        """
      end)
      |> Enum.join("\n")

    arcs_xml =
      net.arcs
      |> Enum.with_index(1)
      |> Enum.map(fn {arc, idx} ->
        {src, dst} =
          case arc do
            %WorkflowNet.Arc{source: s, target: d} -> {s, d}
            {s, d} -> {s, d}
          end

        """
            <arc id="a#{idx}" source="#{src}" target="#{dst}">
              <inscription><text>1</text></inscription>
            </arc>
        """
      end)
      |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <pnml xmlns="http://www.pnml.org/version-2009/grammar/pnml">
      <net id="#{net.id || "net_1"}" type="http://www.pnml.org/version-2009/grammar/ptnet">
        <page id="page_1">
    #{places_xml}
    #{transitions_xml}
    #{arcs_xml}
        </page>
      </net>
    </pnml>
    """
  end
end
