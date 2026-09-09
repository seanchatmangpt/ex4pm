# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.WorkflowNet.Composition do
  @moduledoc """
  Substitutive Composition of Workflow Nets — Exact Mathematical Realization:
  - Definition 3.12 [PETRI25, p. 11]
  - Definition 3.13 [PETRI25, p. 11] (Separable Workflow Nets)

  ## Mathematical Definition (Definition 3.12)

  Let $N = (P, T, F)$ be a Petri net and $t \\in T$. Let $N' = (P', T', F')$ be a WF-net such that $(P \\cup T) \\cap (P' \\cup T') = \\emptyset$.
  The substitutive composition $N[t \\to N']$ is the Petri net $(P'', T'', F'')$ defined by:
    - $P'' = P \\cup (P' \\setminus \\{N'_{source}, N'_{sink}\\})$
    - $T'' = (T \\setminus \\{t\\}) \\cup T'$
    - $F'' = \\{(u, v) \\in F \\mid u \\neq t \\wedge v \\neq t\\} \\cup \\{(u, v) \\in F' \\mid u \\neq N'_{source} \\wedge v \\neq N'_{sink}\\}$
             $\\cup \\{(p, t') \\mid (p, t) \\in F \\wedge (N'_{source}, t') \\in F'\\}$
             $\\cup \\{(t', p) \\mid (t, p) \\in F \\wedge (t', N'_{sink}) \\in F'\\}$

  ## Theorem 5.6 Completeness Property [PETRI25 p. 31]
  Every sound and safe separable WF-net can be decomposed losslessly into POWL 2.0 without fall-through.
  """

  alias Ex4pmEngine.WorkflowNet

  @doc """
  Executes substitutive composition $N[t \\to N']$.
  """
  @spec substitute(WorkflowNet.t(), String.t(), WorkflowNet.t()) ::
          {:ok, WorkflowNet.t()} | {:error, String.t()}
  def substitute(%WorkflowNet{} = n, t_target, %WorkflowNet{} = n_prime) do
    n_trans_keys = if is_map(n.transitions), do: Map.keys(n.transitions), else: n.transitions
    t_target_str = to_string(t_target)

    if t_target_str not in Enum.map(n_trans_keys, &to_string/1) do
      {:error, "transition #{inspect(t_target_str)} not in target net N"}
    else
      n_places = if is_map(n.places), do: Map.keys(n.places), else: n.places

      n_prime_places =
        if is_map(n_prime.places), do: Map.keys(n_prime.places), else: n_prime.places

      n_prime_trans =
        if is_map(n_prime.transitions),
          do: Map.keys(n_prime.transitions),
          else: n_prime.transitions

      p_prime_internal = n_prime_places -- [n_prime.source_place, n_prime.sink_place]
      p_double_prime = Enum.uniq(n_places ++ p_prime_internal)

      t_double_prime =
        Enum.uniq(Enum.reject(n_trans_keys, &(to_string(&1) == t_target_str)) ++ n_prime_trans)

      n_arcs =
        Enum.map(n.arcs, fn
          %WorkflowNet.Arc{source: s, target: d} -> {s, d}
          {s, d} -> {to_string(s), to_string(d)}
        end)

      n_prime_arcs =
        Enum.map(n_prime.arcs, fn
          %WorkflowNet.Arc{source: s, target: d} -> {s, d}
          {s, d} -> {to_string(s), to_string(d)}
        end)

      # Inflow to t_target from N
      in_places =
        Enum.filter(n_arcs, fn {_p, t} -> to_string(t) == t_target_str end)
        |> Enum.map(&elem(&1, 0))

      # Outflow from t_target to N
      out_places =
        Enum.filter(n_arcs, fn {t, _p} -> to_string(t) == t_target_str end)
        |> Enum.map(&elem(&1, 1))

      # Inflow from N'_source to N'
      prime_starts =
        Enum.filter(n_prime_arcs, fn {p, _t} -> p == n_prime.source_place end)
        |> Enum.map(&elem(&1, 1))

      # Outflow from N' to N'_sink
      prime_ends =
        Enum.filter(n_prime_arcs, fn {_t, p} -> p == n_prime.sink_place end)
        |> Enum.map(&elem(&1, 0))

      # Retain non-t arcs from N
      f_n_retained =
        Enum.reject(n_arcs, fn {u, v} ->
          to_string(u) == t_target_str or to_string(v) == t_target_str
        end)

      # Retain internal arcs from N'
      f_prime_retained =
        Enum.reject(n_prime_arcs, fn {u, v} ->
          u == n_prime.source_place or v == n_prime.sink_place
        end)

      # Stitching arcs
      f_stitch_in = for p <- in_places, t_prime <- prime_starts, do: {p, t_prime}
      f_stitch_out = for t_prime <- prime_ends, p <- out_places, do: {t_prime, p}

      f_double_prime = Enum.uniq(f_n_retained ++ f_prime_retained ++ f_stitch_in ++ f_stitch_out)

      WorkflowNet.new(p_double_prime, t_double_prime, f_double_prime,
        source_place: n.source_place,
        sink_place: n.sink_place
      )
    end
  end
end
