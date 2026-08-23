defmodule Ex4pm.Qualification.Powl.BoundedUnfolder do
  @moduledoc "Independent bounded lowering of generalized POWL into finite linear Reactor fragments."

  alias Ex4pm.Qualification.Powl.TraceCanonicalizer
  alias Ex4pmEngine.POWL.{ChoiceGraph, Node}

  def language(model, bound) when is_integer(bound) and bound >= 0 do
    model |> unfold(bound) |> TraceCanonicalizer.canonicalize()
  end

  defp unfold(%Node{operator: :activity, label: label}, _bound), do: [[to_string(label)]]
  defp unfold(%Node{operator: :silent}, _bound), do: [[]]

  defp unfold(%Node{operator: :sequence, children: children}, bound) do
    children |> Enum.map(&unfold(&1, bound)) |> concat_languages()
  end

  defp unfold(%Node{operator: :choice, children: children}, bound) do
    children |> Enum.flat_map(&unfold(&1, bound)) |> Enum.uniq()
  end

  defp unfold(%Node{operator: :loop, children: [body, redo]}, bound) do
    body_lang = unfold(body, bound)
    redo_lang = unfold(redo, bound)

    0..bound
    |> Enum.flat_map(fn repetitions ->
      pieces = [body_lang] ++ List.flatten(List.duplicate([redo_lang, body_lang], repetitions))
      concat_languages(pieces)
    end)
    |> Enum.uniq()
  end

  defp unfold(%Node{operator: :choice_graph, choice_graph: graph}, bound), do: unfold(graph, bound)

  defp unfold(%ChoiceGraph{nodes: nodes, edges: edges}, bound) do
    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))
    max_depth = max(4, (bound + 1) * max(map_size(nodes), 1) * 2)

    successors
    |> graph_paths("▷", [], %{}, bound, max_depth)
    |> Enum.flat_map(fn path ->
      path |> Enum.map(fn id -> unfold(Map.fetch!(nodes, id), bound) end) |> concat_languages()
    end)
    |> Enum.uniq()
  end

  defp unfold(%Node{operator: :partial_order, children: children, order_edges: edges}, bound) do
    ids = Enum.map(children, & &1.id)
    languages = Enum.map(children, &unfold(&1, bound))

    cartesian(languages)
    |> Enum.flat_map(fn traces -> constrained_interleavings(ids, traces, edges) end)
    |> Enum.uniq()
  end

  defp graph_paths(_succ, "□", path, _visits, _bound, _depth), do: [Enum.reverse(path)]
  defp graph_paths(_succ, _node, _path, _visits, _bound, 0), do: []

  defp graph_paths(succ, node, path, visits, bound, depth) do
    Enum.flat_map(Map.get(succ, node, []), fn next ->
      count = Map.get(visits, next, 0)

      if next != "□" and count > bound do
        []
      else
        next_path = if next == "□", do: path, else: [next | path]
        graph_paths(succ, next, next_path, Map.put(visits, next, count + 1), bound, depth - 1)
      end
    end)
  end

  defp constrained_interleavings(ids, traces, edges) do
    states = Enum.zip(ids, traces)
    predecessors = Enum.group_by(edges, &elem(&1, 1), &elem(&1, 0))
    do_interleave(states, predecessors, [])
  end

  defp do_interleave(states, predecessors, prefix) do
    if Enum.all?(states, fn {_id, trace} -> trace == [] end) do
      [Enum.reverse(prefix)]
    else
      completed = states |> Enum.filter(fn {_id, trace} -> trace == [] end) |> MapSet.new(&elem(&1, 0))

      states
      |> Enum.with_index()
      |> Enum.filter(fn {{id, trace}, _index} ->
        trace != [] and Enum.all?(Map.get(predecessors, id, []), &MapSet.member?(completed, &1))
      end)
      |> Enum.flat_map(fn {{id, [head | tail]}, index} ->
        next = List.replace_at(states, index, {id, tail})
        do_interleave(next, predecessors, [head | prefix])
      end)
    end
  end

  defp concat_languages([]), do: [[]]
  defp concat_languages(languages) do
    Enum.reduce(languages, [[]], fn language, acc ->
      for prefix <- acc, suffix <- language, do: prefix ++ suffix
    end)
  end

  defp cartesian([]), do: [[]]
  defp cartesian([head | tail]), do: for(x <- head, rest <- cartesian(tail), do: [x | rest])
end
