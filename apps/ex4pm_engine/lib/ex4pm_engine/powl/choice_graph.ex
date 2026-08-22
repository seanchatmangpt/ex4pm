# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.POWL.ChoiceGraph do
  @moduledoc """
  POWL 2.0 Choice Graph — Exact Mathematical Realization:
  - Definition 1 [BPM25, p. 7]
  - Definition 2 & 3 [BPM25, p. 8]
  - Definition 3.6, 3.7 & 3.9 [PETRI25, pp. 8–10]

  ## Mathematical Formalism

  Let $X$ be a finite set of POWL sub-models (or transitions $T$).
  A choice graph over $X$ is a tuple:
  $$G = (N, E)$$
  where:
    1. $N = X \\cup \\{▷, □\\}$ with $▷, □ \\notin X$ (artificial start $▷$ and end $□$ delimiters).
    2. $E \\subseteq N \\times N$ is a directed binary relation over $N$.
    3. $\\{▷\\} = \\{x \\in N \\mid (N \\times \\{x\\}) \\cap E = \\emptyset\\}$  (unique start node).
    4. $\\{□\\} = \\{x \\in N \\mid (\\{x\\} \\times N) \\cap E = \\emptyset\\}$  (unique end node).
    5. $\\forall n \\in N, \\exists$ a directed path in $E$ from $▷$ to $n$ and from $n$ to $□$.

  ## Language Semantics (Definition 3 [BPM25, p. 8], Definition 3.9 [PETRI25, p. 10])

  Let $\\vec{G}$ denote the set of all directed paths from $▷$ to $□$ in $G$:
  $$\\vec{G} = \\{\\langle x_1, \\dots, x_k \\rangle \\in X^* \\mid (▷, x_1), (x_1, x_2), \\dots, (x_k, □) \\in E\\}$$

  The language of the choice graph is the union of path concatenations:
  $$L(G) = \\bigcup_{\\langle x_1, \\dots, x_k \\rangle \\in \\vec{G}} L(x_1) \\cdot L(x_2) \\cdots L(x_k)$$
  """

  @enforce_keys [:nodes, :edges]
  defstruct [:nodes, :edges, cyclic?: false, metadata: %{}]

  @type node_id :: String.t()
  @type t :: %__MODULE__{
          nodes: %{node_id() => term()},
          edges: [{node_id(), node_id()}],
          cyclic?: boolean(),
          metadata: map()
        }

  @start_delimiter "▷"
  @end_delimiter "□"

  def start_delimiter, do: @start_delimiter
  def end_delimiter, do: @end_delimiter

  @doc """
  Constructs a validated Choice Graph $G = (N, E)$.
  Accepts either `"▷"` / `"□"` or `:start` / `:end` as delimiter identifiers.

  ## Doctests
      iex> a = Ex4pmEngine.POWL.activity("a", "Triage")
      iex> b = Ex4pmEngine.POWL.activity("b", "Approve")
      iex> {:ok, cg} = Ex4pmEngine.POWL.ChoiceGraph.new([a, b], [{"▷", "a"}, {"a", "b"}, {"b", "□"}])
      iex> cg.cyclic?
      false
      iex> Ex4pmEngine.POWL.ChoiceGraph.enumerate_paths(cg)
      [["a", "b"]]
  """
  @spec new([term()], [{String.t(), String.t()}], map()) :: {:ok, t()} | {:error, String.t()}
  def new(nodes, edges, metadata \\ %{}) when is_list(nodes) and is_list(edges) do
    node_map = Map.new(nodes, fn n -> {to_string(Map.get(n, :id, n)), n} end)

    normalized_edges =
      Enum.map(edges, fn {s, d} ->
        s_str = normalize_delimiter(to_string(s))
        d_str = normalize_delimiter(to_string(d))
        {s_str, d_str}
      end)

    with :ok <- validate_delimiters(node_map, normalized_edges),
         :ok <- validate_unique_source_sink(normalized_edges),
         :ok <- validate_full_connectivity(node_map, normalized_edges) do
      cyclic? = detect_cycles(node_map, normalized_edges)
      {:ok, %__MODULE__{nodes: node_map, edges: normalized_edges, cyclic?: cyclic?, metadata: metadata}}
    end
  end

  @doc """
  Enumerates all paths $\\vec{G} = \\{\\langle x_1, \\dots, x_k \\rangle \\in X^* \\mid (▷, x_1), \\dots, (x_k, □) \\in E\\}$.
  For cyclic choice graphs, bounds depth by `max_depth` (default 20) and unrolls by `max_unroll` (default 2).
  """
  @spec enumerate_paths(t(), keyword()) :: [[node_id()]]
  def enumerate_paths(%__MODULE__{edges: edges}, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 20)
    max_unroll = Keyword.get(opts, :max_unroll, 2)
    succ = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    find_paths(succ, @start_delimiter, [], %{}, max_depth, max_unroll)
  end

  defp find_paths(_succ, @end_delimiter, current_path, _visit_counts, _max_d, _max_u) do
    [Enum.reverse(current_path)]
  end

  defp find_paths(succ, curr, current_path, visit_counts, max_d, max_u) do
    if length(current_path) >= max_d do
      []
    else
      next_nodes = Map.get(succ, curr, [])

      Enum.flat_map(next_nodes, fn next ->
        next_count = Map.get(visit_counts, next, 0)

        if next != @end_delimiter and next_count >= max_u do
          []
        else
          new_path = if next == @end_delimiter, do: current_path, else: [next | current_path]
          new_counts = Map.put(visit_counts, next, next_count + 1)
          find_paths(succ, next, new_path, new_counts, max_d, max_u)
        end
      end)
    end
  end

  defp normalize_delimiter(str) do
    case str do
      "start" -> @start_delimiter
      ":start" -> @start_delimiter
      "end" -> @end_delimiter
      ":end" -> @end_delimiter
      other -> other
    end
  end

  defp validate_delimiters(node_map, edges) do
    valid_ids = MapSet.put(MapSet.new(Map.keys(node_map)), @start_delimiter) |> MapSet.put(@end_delimiter)
    edge_ids = Enum.flat_map(edges, fn {s, d} -> [s, d] end) |> MapSet.new()

    unknown = MapSet.difference(edge_ids, valid_ids)
    if MapSet.size(unknown) == 0, do: :ok, else: {:error, "unknown edge nodes: #{inspect(MapSet.to_list(unknown))}"}
  end

  defp validate_unique_source_sink(edges) do
    sources = Enum.map(edges, &elem(&1, 0)) |> MapSet.new()
    targets = Enum.map(edges, &elem(&1, 1)) |> MapSet.new()

    cond do
      MapSet.member?(targets, @start_delimiter) ->
        {:error, "unique start node condition violated: {▷} has incoming edges (Def. 1 [BPM25])"}

      MapSet.member?(sources, @end_delimiter) ->
        {:error, "unique end node condition violated: {□} has outgoing edges (Def. 1 [BPM25])"}

      not MapSet.member?(sources, @start_delimiter) ->
        {:error, "unique start node {▷} must have at least one outgoing edge"}

      not MapSet.member?(targets, @end_delimiter) ->
        {:error, "unique end node {□} must have at least one incoming edge"}

      true ->
        :ok
    end
  end

  defp validate_full_connectivity(node_map, edges) do
    succ = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))
    pred = Enum.group_by(edges, &elem(&1, 1), &elem(&1, 0))

    from_start = bfs_reach(@start_delimiter, succ)
    to_end = bfs_reach(@end_delimiter, pred)

    unreachable =
      Enum.reject(Map.keys(node_map), fn id ->
        MapSet.member?(from_start, id) and MapSet.member?(to_end, id)
      end)

    if unreachable == [] do
      :ok
    else
      {:error, "nodes not on connected path ▷ → n → □: #{inspect(unreachable)} (Def. 1 [BPM25])"}
    end
  end

  defp detect_cycles(node_map, edges) do
    succ = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))
    nodes = Map.keys(node_map)
    Enum.any?(nodes, fn id -> id in bfs_reach(id, succ, skip_root?: true) end)
  end

  defp bfs_reach(root, adj, opts \\ []) do
    skip_root? = Keyword.get(opts, :skip_root?, false)
    initial_visited = if skip_root?, do: MapSet.new(), else: MapSet.new([root])
    queue = Map.get(adj, root, [])
    do_bfs(queue, adj, initial_visited)
  end

  defp do_bfs([], _adj, visited), do: visited
  defp do_bfs([curr | rest], adj, visited) do
    if MapSet.member?(visited, curr) do
      do_bfs(rest, adj, visited)
    else
      nexts = Map.get(adj, curr, [])
      do_bfs(rest ++ nexts, adj, MapSet.put(visited, curr))
    end
  end
end
