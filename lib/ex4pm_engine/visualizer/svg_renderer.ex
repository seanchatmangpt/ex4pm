# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Visualizer.SVGRenderer do
  @moduledoc """
  Native SVG Layout & Vector Visualizer for POWL 2.0 ChoiceGraphs, Workflow Nets, and BPMN models.
  """

  alias Ex4pmEngine.POWL.{ChoiceGraph, Node}
  alias Ex4pmEngine.WorkflowNet

  @doc "Renders a POWL 2.0 ChoiceGraph or Node as an interactive SVG vector image."
  @spec render_powl(Node.t() | ChoiceGraph.t()) :: String.t()
  def render_powl(%Node{operator: :choice_graph, choice_graph: cg}) do
    render_powl(cg)
  end

  def render_powl(%ChoiceGraph{} = cg) do
    # Simple layered horizontal layout for SVG
    node_ids = Map.keys(cg.nodes)
    start_del = ChoiceGraph.start_delimiter()
    end_del = ChoiceGraph.end_delimiter()
    all_render_ids = [start_del | node_ids] ++ [end_del]

    spacing = 150
    y_pos = 120

    positions =
      all_render_ids
      |> Enum.with_index()
      |> Map.new(fn {id, idx} -> {id, {80 + idx * spacing, y_pos}} end)

    width = max(600, (length(all_render_ids) + 1) * spacing)
    height = 240

    nodes_svg =
      Enum.map(all_render_ids, fn id ->
        {x, y} = Map.fetch!(positions, id)
        label = if id in [start_del, end_del], do: id, else: Map.get(cg.nodes[id], :label, id)
        color = if id in [start_del, end_del], do: "#10b981", else: "#3b82f6"

        """
        <g class="node" transform="translate(#{x}, #{y})">
          <circle r="26" fill="#{color}" stroke="#1e293b" stroke-width="2.5" />
          <text text-anchor="middle" dy="5" fill="#ffffff" font-family="system-ui" font-size="13" font-weight="600">#{label}</text>
        </g>
        """
      end)
      |> Enum.join("\n")

    edges_svg =
      Enum.map(cg.edges, fn {src, dst} ->
        {x1, y1} = Map.fetch!(positions, src)
        {x2, y2} = Map.fetch!(positions, dst)

        """
        <line x1="#{x1 + 26}" y1="#{y1}" x2="#{x2 - 26}" y2="#{y2}" stroke="#64748b" stroke-width="2" marker-end="url(#arrow)" />
        """
      end)
      |> Enum.join("\n")

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{width} #{height}" width="100%" height="240">
      <defs>
        <marker id="arrow" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path d="M 0 0 L 10 5 L 0 10 z" fill="#64748b" />
        </marker>
      </defs>
      <rect width="100%" height="100%" fill="#f8fafc" rx="8" />
    #{edges_svg}
    #{nodes_svg}
    </svg>
    """
  end

  def render_powl(other) do
    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 120" width="100%" height="120">
      <rect width="100%" height="100%" fill="#f8fafc" rx="8" />
      <text x="50%" y="50%" text-anchor="middle" font-family="system-ui" fill="#475569">POWL: #{inspect(other)}</text>
    </svg>
    """
  end

  @doc "Renders a Workflow Net as an SVG Petri Net."
  @spec render_petri_net(WorkflowNet.t()) :: String.t()
  def render_petri_net(%WorkflowNet{} = net) do
    places_count = map_size(net.places)
    trans_count = map_size(net.transitions)
    total_nodes = places_count + trans_count

    width = max(600, total_nodes * 90)
    height = 220

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{width} #{height}" width="100%" height="220">
      <rect width="100%" height="100%" fill="#f8fafc" rx="8" />
      <text x="20" y="30" font-family="system-ui" font-weight="700" fill="#0f172a">Petri Net (Places: #{places_count}, Transitions: #{trans_count})</text>
      <!-- Visualized Places -->
      #{render_pn_places(net)}
    </svg>
    """
  end

  def render_bpmn(model) do
    render_powl(model)
  end

  defp render_pn_places(net) do
    net.places
    |> Map.keys()
    |> Enum.with_index()
    |> Enum.map(fn {p_id, idx} ->
      x = 60 + idx * 110

      """
      <circle cx="#{x}" cy="110" r="22" fill="#e2e8f0" stroke="#0f172a" stroke-width="2" />
      <text x="#{x}" y="115" text-anchor="middle" font-family="system-ui" font-size="11">#{p_id}</text>
      """
    end)
    |> Enum.join("\n")
  end
end
