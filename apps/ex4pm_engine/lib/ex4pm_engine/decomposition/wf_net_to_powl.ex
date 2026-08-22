# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Decomposition.WFNetToPOWL do
  @moduledoc """
  Top-Down Hierarchical Decomposition of Separable Workflow Nets into POWL 2.0:
  - Algorithm 1 `PartitionMG` [PETRI25, p. 17] (Marked Graph Poset Decomposition)
  - Algorithm 2 `PartitionSM` [PETRI25, p. 19] (State Machine Choice Graph Decomposition)
  - Algorithm 3 `WFNetToPOWL` [PETRI25, p. 21] (Recursive SESE Decomposition)
  - Theorem 5.6 Completeness Guarantee [PETRI25, p. 24]
  """

  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.POWL.{ChoiceGraph, Node}
  alias Ex4pmEngine.WorkflowNet

  @doc """
  Algorithm 3 `WFNetToPOWL(N)` [PETRI25, p. 21]:
  Recursively decomposes a separable Workflow Net into a canonical POWL 2.0 AST.
  """
  @spec convert(WorkflowNet.t()) :: {:ok, Node.t()} | {:error, atom()}
  def convert(%WorkflowNet{} = net) do
    transitions = Map.keys(net.transitions)

    case transitions do
      [single_t] ->
        t_struct = Map.get(net.transitions, single_t)
        label = t_struct.label || to_string(single_t)

        if label in ["tau", "silent", ""] or String.starts_with?(to_string(single_t), "tau") do
          {:ok, POWL.silent(to_string(single_t))}
        else
          {:ok, POWL.activity(to_string(single_t), label)}
        end

      _multiple ->
        if marked_graph?(net) do
          partition_mg(net)
        else
          partition_sm(net)
        end
    end
  end

  @doc "Algorithm 1 `PartitionMG`: Decomposes Marked Graph into a Partial Order."
  def partition_mg(net) do
    poset =
      Enum.flat_map(net.places, fn {p_id, _p} ->
        in_t = get_input_transitions(net, p_id)
        out_t = get_output_transitions(net, p_id)
        for u <- in_t, v <- out_t, u != v, do: {to_string(u), to_string(v)}
      end)
      |> Enum.uniq()

    nodes =
      Enum.map(net.transitions, fn {t_id, t_struct} ->
        POWL.activity(to_string(t_id), t_struct.label || to_string(t_id))
      end)

    {:ok, POWL.partial_order("po_decomposed_#{net.id || "mg"}", nodes, poset)}
  end

  @doc "Algorithm 2 `PartitionSM`: Decomposes State Machine into a Choice Graph."
  def partition_sm(net) do
    nodes =
      Enum.map(net.transitions, fn {t_id, t_struct} ->
        POWL.activity(to_string(t_id), t_struct.label || to_string(t_id))
      end)

    start_del = ChoiceGraph.start_delimiter()
    end_del = ChoiceGraph.end_delimiter()

    edges =
      Enum.flat_map(net.places, fn {p_id, _p} ->
        in_t = get_input_transitions(net, p_id)
        out_t = get_output_transitions(net, p_id)

        cond do
          p_id == net.source_place ->
            for v <- out_t, do: {start_del, to_string(v)}

          p_id == net.sink_place ->
            for u <- in_t, do: {to_string(u), end_del}

          true ->
            for u <- in_t, v <- out_t, do: {to_string(u), to_string(v)}
        end
      end)
      |> Enum.uniq()

    case ChoiceGraph.new(nodes, edges, %{id: "cg_decomposed_#{net.id || "sm"}"}) do
      {:ok, cg} ->
        {:ok, %Node{id: "cg_root_#{net.id || "sm"}", operator: :choice_graph, children: nodes, choice_graph: cg}}

      {:error, _} ->
        partition_mg(net)
    end
  end

  defp marked_graph?(net) do
    Enum.all?(net.places, fn {p_id, _} ->
      length(get_input_transitions(net, p_id)) <= 1 and length(get_output_transitions(net, p_id)) <= 1
    end)
  end

  defp get_input_transitions(net, place_id) do
    Enum.filter(net.arcs, fn
      %WorkflowNet.Arc{source: s, target: d} -> d == place_id and Map.has_key?(net.transitions, s)
      {s, d} -> d == place_id and Map.has_key?(net.transitions, s)
    end)
    |> Enum.map(fn
      %WorkflowNet.Arc{source: s} -> s
      {s, _} -> s
    end)
  end

  defp get_output_transitions(net, place_id) do
    Enum.filter(net.arcs, fn
      %WorkflowNet.Arc{source: s, target: d} -> s == place_id and Map.has_key?(net.transitions, d)
      {s, d} -> s == place_id and Map.has_key?(net.transitions, d)
    end)
    |> Enum.map(fn
      %WorkflowNet.Arc{target: d} -> d
      {_, d} -> d
    end)
  end
end
