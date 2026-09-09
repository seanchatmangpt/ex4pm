defmodule Ex4pm.Qualification.Powl.ReferenceOracle do
  @moduledoc """
  Independent declarative bounded-language interpreter for POWL 2.0 syntax.

  This module deliberately does not call `Ex4pmEngine.POWL.Language`,
  `Ex4pmEngine.POWL.Shuffle`, or the qualification bounded compiler. It shares
  only immutable syntax structs with the implementation under test.
  """

  alias Ex4pm.Qualification.Powl.TraceCanonicalizer
  alias Ex4pmEngine.POWL.{ChoiceGraph, Node}

  def language(model, bound) when is_integer(bound) and bound >= 0 do
    model
    |> interpret(bound)
    |> TraceCanonicalizer.canonicalize()
  end

  defp interpret(%Node{operator: :activity, label: label}, _bound),
    do: [[to_string(label)]]

  defp interpret(%Node{operator: :silent}, _bound), do: [[]]

  defp interpret(%Node{operator: :sequence, children: children}, bound) do
    children
    |> Enum.map(&interpret(&1, bound))
    |> language_product()
  end

  defp interpret(%Node{operator: :choice, children: children}, bound) do
    children
    |> Enum.flat_map(&interpret(&1, bound))
    |> Enum.uniq()
  end

  defp interpret(%Node{operator: :loop, children: [body, redo]}, bound) do
    body_language = interpret(body, bound)
    redo_language = interpret(redo, bound)

    for repeats <- 0..bound,
        trace <- loop_language(body_language, redo_language, repeats),
        uniq: true,
        do: trace
  end

  defp interpret(%Node{operator: :choice_graph, choice_graph: graph}, bound),
    do: interpret(graph, bound)

  defp interpret(%ChoiceGraph{nodes: nodes, edges: edges}, bound) do
    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))
    allowed_visits = bound + 1

    successors
    |> enumerate_paths("▷", [], %{}, allowed_visits)
    |> Enum.flat_map(fn path ->
      path
      |> Enum.map(fn id -> interpret(Map.fetch!(nodes, id), bound) end)
      |> language_product()
    end)
    |> Enum.uniq()
  end

  defp interpret(%Node{operator: :partial_order, children: children, order_edges: edges}, bound) do
    ids = Enum.map(children, & &1.id)
    languages = Enum.map(children, &interpret(&1, bound))

    languages
    |> cartesian()
    |> Enum.flat_map(fn child_traces ->
      ids
      |> Enum.zip(child_traces)
      |> Enum.map(fn {id, trace} ->
        trace
        |> Enum.with_index()
        |> Enum.map(fn {label, index} -> {id, index, label} end)
      end)
      |> stable_shuffles()
      |> Enum.filter(&respects_order?(&1, edges))
      |> Enum.map(fn tagged -> Enum.map(tagged, &elem(&1, 2)) end)
    end)
    |> Enum.uniq()
  end

  defp loop_language(body, _redo, 0), do: body

  defp loop_language(body, redo, repeats) do
    cycle = language_product([body, redo])
    prefix = Enum.reduce(1..repeats, [[]], fn _, acc -> language_product([acc, cycle]) end)
    language_product([prefix, body])
  end

  defp enumerate_paths(_successors, "□", path, _visits, _allowed),
    do: [Enum.reverse(path)]

  defp enumerate_paths(successors, node, path, visits, allowed) do
    Enum.flat_map(Map.get(successors, node, []), fn next ->
      cond do
        next == "□" ->
          enumerate_paths(successors, next, path, visits, allowed)

        Map.get(visits, next, 0) >= allowed ->
          []

        true ->
          enumerate_paths(
            successors,
            next,
            [next | path],
            Map.update(visits, next, 1, &(&1 + 1)),
            allowed
          )
      end
    end)
  end

  # Enumerate all interleavings while preserving each child's internal order.
  # This algorithm is intentionally structurally different from the production
  # shuffle and from `BoundedUnfolder`'s completion-state algorithm.
  defp stable_shuffles(sequences), do: do_stable_shuffles(sequences, [])

  defp do_stable_shuffles(sequences, prefix) do
    if Enum.all?(sequences, &(&1 == [])) do
      [Enum.reverse(prefix)]
    else
      sequences
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {[], _index} ->
          []

        {[head | tail], index} ->
          next = List.replace_at(sequences, index, tail)
          do_stable_shuffles(next, [head | prefix])
      end)
    end
  end

  # POWL partial-order edges constrain whole child models: every occurrence
  # emitted by the predecessor must precede every occurrence of the successor.
  defp respects_order?(tagged_trace, edges) do
    positions =
      tagged_trace
      |> Enum.with_index()
      |> Enum.group_by(fn {{id, _event_index, _label}, _position} -> id end, fn {_event, position} ->
        position
      end)

    Enum.all?(edges, fn {left, right} ->
      left_positions = Map.get(positions, left, [])
      right_positions = Map.get(positions, right, [])

      left_positions == [] or right_positions == [] or
        Enum.max(left_positions) < Enum.min(right_positions)
    end)
  end

  defp language_product([]), do: [[]]

  defp language_product(languages) do
    Enum.reduce(languages, [[]], fn language, prefixes ->
      for prefix <- prefixes, suffix <- language, do: prefix ++ suffix
    end)
  end

  defp cartesian([]), do: [[]]

  defp cartesian([head | tail]),
    do: for(value <- head, rest <- cartesian(tail), do: [value | rest])
end
