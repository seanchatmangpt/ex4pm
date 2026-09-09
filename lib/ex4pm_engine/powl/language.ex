# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.POWL.Language do
  @moduledoc """
  POWL 2.0 Language Evaluator $L(\\psi)$ — Exact Mathematical Realization:
  - Definition 3 [BPM25, p. 8]
  - Definition 3.9 [PETRI25, p. 10]

  ## Mathematical Definition

  The language of a POWL 2.0 model $\\psi$ is defined recursively:
    1. $L(t) = \\{\\langle a \\rangle\\}$ for $t \\in T$ with $l(t) = a \\in \\Sigma$.
    2. $L(t) = \\{\\langle\\rangle\\}$ for $t \\in T$ with $l(t) = \\tau$.
    3. $L(\\circlearrowleft(\\psi_1, \\psi_2)) = L(\\psi_1) \\cdot (L(\\psi_2) \\cdot L(\\psi_1))^*$.
    4. $L(\\prec(\\psi_1, \\dots, \\psi_n)) = \\{\\sigma \\in \\prec\\hspace{-0.6em}\\odot(\\sigma_1, \\dots, \\sigma_n) \\mid \\forall i, \\sigma_i \\in L(\\psi_i)\\}$.
    5. $L(G) = \\bigcup_{\\langle x_1, \\dots, x_k \\rangle \\in \\vec{G}} L(x_1) \\cdot L(x_2) \\cdots L(x_k)$.
  """

  alias Ex4pmEngine.POWL.{ChoiceGraph, Node, Shuffle}

  @doc """
  Computes the finite bounded language approximation $L(\\psi)$ of a POWL 2.0 model.
  """
  @spec evaluate(Node.t() | ChoiceGraph.t(), keyword()) :: [[String.t()]]
  def evaluate(model, opts \\ [])

  def evaluate(%Node{operator: :activity, label: label}, _opts) do
    [[label]]
  end

  def evaluate(%Node{operator: :silent}, _opts) do
    [[]]
  end

  def evaluate(%Node{operator: :sequence, children: children}, opts) do
    child_languages = Enum.map(children, &evaluate(&1, opts))

    Enum.reduce(child_languages, [[]], fn child_lang, acc ->
      for prefix <- acc, suffix <- child_lang, do: prefix ++ suffix
    end)
  end

  def evaluate(%Node{operator: :choice, children: children}, opts) do
    Enum.flat_map(children, &evaluate(&1, opts)) |> Enum.uniq()
  end

  def evaluate(%Node{operator: :choice_graph, choice_graph: cg}, opts) do
    evaluate(cg, opts)
  end

  def evaluate(%ChoiceGraph{} = cg, opts) do
    paths = ChoiceGraph.enumerate_paths(cg, opts)

    Enum.flat_map(paths, fn path_node_ids ->
      path_nodes = Enum.map(path_node_ids, fn id -> Map.fetch!(cg.nodes, id) end)
      child_languages = Enum.map(path_nodes, &evaluate(&1, opts))

      Enum.reduce(child_languages, [[]], fn child_lang, acc ->
        for prefix <- acc, suffix <- child_lang, do: prefix ++ suffix
      end)
    end)
    |> Enum.uniq()
  end

  def evaluate(%Node{operator: :partial_order, children: children, order_edges: edges}, opts) do
    child_languages = Enum.map(children, &evaluate(&1, opts))
    child_ids = Enum.map(children, & &1.id)

    # Convert node_id edges into 1-based index poset
    id_to_idx = Enum.with_index(child_ids, 1) |> Map.new()

    poset =
      Enum.map(edges, fn {src, dst} ->
        {Map.fetch!(id_to_idx, src), Map.fetch!(id_to_idx, dst)}
      end)

    # Cross product of child languages, then apply op_shuffle
    cartesian(child_languages)
    |> Enum.flat_map(fn sequence_tuple ->
      Shuffle.op_shuffle(sequence_tuple, poset)
    end)
    |> Enum.uniq()
  end

  def evaluate(%Node{operator: :loop, children: [body, redo_node]}, opts) do
    max_unroll = Keyword.get(opts, :max_unroll, 2)
    body_lang = evaluate(body, opts)
    redo_lang = evaluate(redo_node, opts)

    # 0 unrolls: L(body)
    # 1 unroll: L(body) . L(redo) . L(body)
    # 2 unrolls: L(body) . L(redo) . L(body) . L(redo) . L(body)
    Enum.flat_map(0..max_unroll, fn k ->
      unroll_loop(body_lang, redo_lang, k)
    end)
    |> Enum.uniq()
  end

  defp unroll_loop(body_lang, _redo_lang, 0), do: body_lang

  defp unroll_loop(body_lang, redo_lang, k) do
    step_lang =
      for b <- body_lang, r <- redo_lang do
        b ++ r
      end

    prefix =
      Enum.reduce(1..k, [[]], fn _, acc ->
        for p <- acc, s <- step_lang, do: p ++ s
      end)

    for p <- prefix, b <- body_lang, do: p ++ b
  end

  defp cartesian([]), do: [[]]

  defp cartesian([h | t]) do
    for x <- h, y <- cartesian(t), do: [x | y]
  end
end
