# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.POWL.Shuffle do
  @moduledoc """
  Order-Preserving Shuffle Operator $\\prec\\hspace{-0.6em}\\odot$ — Exact Mathematical Realization:
  - Definition 3.8 [PETRI25, p. 10]
  - Section 3.1 [BPM25, p. 6]

  ## Mathematical Definition

  Let $\\sigma_1, \\dots, \\sigma_n \\in X^*$ be sequences over a set $X$ with $n \\ge 2$, and let $\\prec \\;\\in \\mathcal{O}_n$ be a strict partial order.
  Let $I = \\{(j, k) \\mid 1 \\le j \\le n \\wedge 1 \\le k \\le |\\sigma_j|\\}$ be the set of all indexed positions.
  The order-preserving shuffle operator $\\prec\\hspace{-0.6em}\\odot(\\sigma_1, \\dots, \\sigma_n)$ is defined as:

  $$\\prec\\hspace{-0.6em}\\odot(\\sigma_1, \\dots, \\sigma_n) = \\left\\{\\sigma \\in X^* \\;\\middle|\\; \\begin{aligned} &|\\sigma| = |I| \\;\\wedge\\; \\exists f \\in \\mathcal{B}(I, \\{1,\\dots,|\\sigma|\\}) \\text{ s.t. } \\forall (j,k) \\in I, \\sigma(f(j,k)) = \\sigma_j(k) \\\\ &\\wedge \\forall (j_1,k_1),(j_2,k_2) \\in I, (j_1 \\prec j_2 \\vee (j_1=j_2 \\wedge k_1 < k_2)) \\implies f(j_1,k_1) < f(j_2,k_2) \\end{aligned}\\right\\}$$
  """

  @doc """
  Computes the complete multiset/set of valid order-preserving interleavings $\\prec\\hspace{-0.6em}\\odot(\\sigma_1, \\dots, \\sigma_n)$.

  ## Doctests [PETRI25 p. 10 Example]
      iex> s1 = ["a", "b"]
      iex> s2 = ["c"]
      iex> s3 = ["d", "e"]
      iex> poset = [{1, 2}, {1, 3}]  # 1 ≺ 2 and 1 ≺ 3
      iex> traces = Ex4pmEngine.POWL.Shuffle.op_shuffle([s1, s2, s3], poset)
      iex> length(traces)
      3
      iex> ["a", "b", "c", "d", "e"] in traces
      true
      iex> ["a", "b", "d", "c", "e"] in traces
      true
      iex> ["a", "b", "d", "e", "c"] in traces
      true
  """
  @spec op_shuffle([[term()]], [{pos_integer(), pos_integer()}]) :: [[term()]]
  def op_shuffle(sequences, poset) when is_list(sequences) and is_list(poset) do
    indexed_seqs =
      sequences
      |> Enum.with_index(1)
      |> Enum.map(fn {seq, j} ->
        Enum.with_index(seq, 1) |> Enum.map(fn {val, k} -> {j, k, val} end)
      end)

    order_map = Enum.group_by(poset, &elem(&1, 0), &elem(&1, 1))

    generate_interleavings(indexed_seqs, order_map, [])
    |> Enum.map(fn trace -> Enum.map(trace, fn {_j, _k, val} -> val end) end)
    |> Enum.uniq()
  end

  defp generate_interleavings(indexed_seqs, order_map, acc) do
    active_seqs = Enum.reject(indexed_seqs, &(&1 == []))

    if active_seqs == [] do
      [Enum.reverse(acc)]
    else
      eligible_heads =
        Enum.filter(active_seqs, fn [{j, _k, _val} | _] ->
          preds = find_predecessors(j, order_map)

          Enum.all?(preds, fn pred_j ->
            case Enum.find(indexed_seqs, fn s -> match?([{^pred_j, _, _} | _], s) end) do
              nil -> true
              [] -> true
              _ -> false
            end
          end)
        end)

      Enum.flat_map(eligible_heads, fn [head | _] ->
        {j, _, _} = head

        new_seqs =
          Enum.map(indexed_seqs, fn
            [{^j, _, _} | tail] -> tail
            other -> other
          end)

        generate_interleavings(new_seqs, order_map, [head | acc])
      end)
    end
  end

  defp find_predecessors(target_j, order_map) do
    Enum.flat_map(order_map, fn {src, dsts} ->
      if target_j in dsts, do: [src], else: []
    end)
  end
end
