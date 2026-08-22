defmodule Ex4pmEngine.POWL.Node do
  @moduledoc """
  A recursively composable node in the POWL 2.0 execution representation.

  `:activity` and `:silent` are atomic nodes. `:partial_order` and `:choice`
  recursively compose POWL submodels. `:loop` is accepted only as a legacy
  input tag and is normalized to the cyclic choice-graph construction defined
  by POWL 2.0 before admission.
  """

  @enforce_keys [:id, :type]
  defstruct [
    :id,
    :type,
    label: nil,
    children: [],
    edges: [],
    choice_graph: %{nodes: [], edges: []},
    loop_body: nil,
    loop_redo: nil,
    loop_exit: nil,
    embedded: %{},
    metadata: %{}
  ]

  @type node_type :: :activity | :silent | :partial_order | :choice | :loop
  @type t :: %__MODULE__{
          id: String.t(),
          type: node_type(),
          label: String.t() | nil,
          children: [String.t()],
          edges: [{String.t(), String.t()}],
          choice_graph: %{nodes: [String.t()], edges: [{String.t(), String.t()}]},
          loop_body: String.t() | nil,
          loop_redo: String.t() | nil,
          loop_exit: String.t() | nil,
          embedded: %{optional(String.t()) => t()},
          metadata: map()
        }
end

defmodule Ex4pmEngine.POWL do
  @moduledoc """
  Executable POWL 2.0 semantics aligned with the formal process-mining literature.

  The canonical grammar implemented here is the 2026 POWL 2.0 definition:

      ψ ::= a | τ | ≺(ψ₁,…,ψₙ) | G({ψ₁,…,ψₙ})

  where `a ∈ Σ`, `τ` is silent behavior, `≺` is a strict partial order, and a
  choice graph is `G = (N,E)` with `N = X ∪ {▷, □}`. `▷` is the unique source,
  `□` is the unique sink, and every graph node lies on a path from `▷` to `□`.

  The trace semantics are executable:

      ℒ(a) = {⟨a⟩}
      ℒ(τ) = {⟨⟩}
      ℒ(≺(ψ₁,…,ψₙ)) = ⋃ (ℒ(ψ₁) ⧢_≺ … ⧢_≺ ℒ(ψₙ))
      ℒ(G) = ⋃_{π∈G⃗} ℒ(ψ'₁) · … · ℒ(ψ'ₖ)

  `language/2` is a finite materialization of `ℒ`. It is exact for finite
  choice graphs when `max_traces` does not truncate the result. Cyclic choice
  graphs denote infinite languages, so their materialization is explicitly
  bounded by `max_choice_visits` (or the compatibility option
  `max_loop_iterations`). `accepts?/3` is therefore a bounded membership check,
  never an unqualified proof over an infinite language.

  Standard process-tree operators are derived constructs, not extra semantic
  node kinds:

      +(ψ₁,…,ψₙ)  = ≺ with the empty relation
      →(ψ₁,…,ψₙ)  = ≺ with {(i,j) | 1 ≤ i < j ≤ n}
      ×(ψ₁,…,ψₙ)  = ▷→ψᵢ→□ for every i
      ↺(ψ₁,ψ₂)    = {(▷,ψ₁),(ψ₁,□),(ψ₁,ψ₂),(ψ₂,ψ₁)}

  ## Executable paper correspondences

      iex> alias Ex4pmEngine.POWL
      iex> tau = POWL.silent("τ")
      iex> {:ok, model} = POWL.new(tau)
      iex> POWL.language(model)
      {:ok, [[]]}

      iex> alias Ex4pmEngine.POWL
      iex> a = POWL.activity("a", "a")
      iex> b = POWL.activity("b", "b")
      iex> {:ok, model} = POWL.new(POWL.concurrent("+", [a, b]))
      iex> POWL.language(model)
      {:ok, [["a", "b"], ["b", "a"]]}

      iex> alias Ex4pmEngine.POWL
      iex> a = POWL.activity("a", "a")
      iex> b = POWL.activity("b", "b")
      iex> {:ok, model} = POWL.new(POWL.sequence("→", [a, b]))
      iex> POWL.language(model)
      {:ok, [["a", "b"]]}

      iex> alias Ex4pmEngine.POWL
      iex> a = POWL.activity("a", "a")
      iex> b = POWL.activity("b", "b")
      iex> {:ok, model} = POWL.new(POWL.choice("×", [a, b]))
      iex> POWL.language(model)
      {:ok, [["a"], ["b"]]}

      iex> alias Ex4pmEngine.POWL
      iex> a = POWL.activity("a", "a")
      iex> b = POWL.activity("b", "b")
      iex> {:ok, model} = POWL.new(POWL.loop("↺", a, b))
      iex> {:ok, traces} = POWL.language(model, max_loop_iterations: 1)
      iex> ["a"] in traces and ["a", "b", "a"] in traces
      true

  The order-preserving shuffle is event-level. If `σ₁ = ⟨a,b⟩`,
  `σ₂ = ⟨c⟩`, `σ₃ = ⟨d,e⟩`, and `1 ≺ 2`, `1 ≺ 3`, then:

      iex> alias Ex4pmEngine.POWL
      iex> a = POWL.activity("a", "a")
      iex> b = POWL.activity("b", "b")
      iex> c = POWL.activity("c", "c")
      iex> d = POWL.activity("d", "d")
      iex> e = POWL.activity("e", "e")
      iex> sigma1 = POWL.sequence("σ₁", [a, b])
      iex> sigma3 = POWL.sequence("σ₃", [d, e])
      iex> root = POWL.partial_order("≺", [sigma1, c, sigma3], [{"σ₁", "c"}, {"σ₁", "σ₃"}])
      iex> {:ok, model} = POWL.new(root)
      iex> POWL.language(model)
      {:ok, [["a", "b", "c", "d", "e"], ["a", "b", "d", "c", "e"], ["a", "b", "d", "e", "c"]]}

  ## References

  * H. Kourani and S. J. van Zelst, “POWL: Partially Ordered Workflow
    Language”, BPM 2023, DOI 10.1007/978-3-031-41620-0_6.
  * H. Kourani, G. Park, and W. M. P. van der Aalst, “Unlocking
    Non-Block-Structured Decisions: Inductive Mining with Choice Graphs”,
    BPM 2025, DOI 10.1007/978-3-032-02867-9_10.
  * H. Kourani, G. Park, and W. M. P. van der Aalst, “A discovery technique
    for expressive yet sound process models”, Process Science 3, 14 (2026),
    DOI 10.1007/s44311-026-00046-8.
  """

  alias Ex4pm.Refusal
  alias Ex4pm.Subject
  alias Ex4pmEngine.POWL.Node
  alias Ex4pmEngine.WorkflowNet
  alias Ex4pmEngine.WorkflowNet.{Arc, Place, Transition}

  @choice_start "▷"
  @choice_end "□"

  @enforce_keys [:id, :root, :nodes]
  defstruct [:id, :root, :nodes, metadata: %{}, subject: nil]

  @type t :: %__MODULE__{
          id: String.t(),
          root: String.t(),
          nodes: %{optional(String.t()) => Node.t()},
          metadata: map(),
          subject: Subject.t() | nil
        }

  @doc "Returns the distinguished choice-graph source symbol `▷`."
  def choice_start, do: @choice_start

  @doc "Returns the distinguished choice-graph sink symbol `□`."
  def choice_end, do: @choice_end

  @doc "Creates an observable activity `a ∈ Σ`."
  def activity(id, label \\ nil, metadata \\ %{}) do
    id = to_string(id)
    %Node{id: id, type: :activity, label: to_string(label || id), metadata: metadata}
  end

  @doc "Creates the silent POWL activity `τ`, whose language is `{⟨⟩}`."
  def silent(id, metadata \\ %{}) do
    %Node{id: to_string(id), type: :silent, metadata: metadata}
  end

  @doc """
  Creates `≺(ψ₁,…,ψₙ)`.

  The supplied edge set may be a Hasse-style cover relation; the constructor
  stores its transitive closure so the admitted relation itself is a strict
  partial order rather than merely a DAG encoding.
  """
  def partial_order(id, children, edges \\ [], metadata \\ %{}) do
    {child_ids, embedded} = normalize_children(children)
    relation = edges |> normalize_relation_edges() |> transitive_closure()

    %Node{
      id: to_string(id),
      type: :partial_order,
      children: child_ids,
      edges: relation,
      embedded: embedded,
      metadata: metadata
    }
  end

  @doc "Creates the parallel operator `+(ψ₁,…,ψₙ)` as an empty strict partial order."
  def concurrent(id, children, metadata \\ %{}) do
    partial_order(id, children, [], metadata)
  end

  @doc "Creates the sequence operator `→(ψ₁,…,ψₙ)` as a total strict partial order."
  def sequence(id, children, metadata \\ %{}) do
    ids = Enum.map(children, &node_id/1)

    edges =
      for {left, i} <- Enum.with_index(ids),
          {right, j} <- Enum.with_index(ids),
          i < j,
          do: {left, right}

    partial_order(id, children, edges, metadata)
  end

  @doc """
  Creates XOR `×(ψ₁,…,ψₙ)`.

  For compatibility, passing `choice_edges:` constructs the explicitly
  supplied choice graph. Without that option, every child is one complete
  `▷ → ψᵢ → □` path.
  """
  def choice(id, children, opts \\ []) do
    metadata =
      opts
      |> Keyword.get(:metadata, %{})
      |> Map.put_new(:derived_operator, :xor)

    edges =
      case Keyword.fetch(opts, :choice_edges) do
        {:ok, supplied} -> supplied
        :error -> xor_edges(children)
      end

    choice_graph(id, children, edges, metadata)
  end

  @doc """
  Creates a POWL 2.0 choice graph.

  Edges are directed execution edges, not pairwise conflict annotations.
  Cycles are legal when the graph still has unique `▷`/`□` terminals and every
  node remains on a `▷ → … → □` path.
  """
  def choice_graph(id, children, choice_edges, metadata \\ %{}) do
    {child_ids, embedded} = normalize_children(children)
    metadata = Map.put_new(metadata, :choice_graph_semantics, :directed_paths)

    %Node{
      id: to_string(id),
      type: :choice,
      children: child_ids,
      choice_graph: %{nodes: child_ids, edges: normalize_choice_edges(choice_edges)},
      embedded: embedded,
      metadata: metadata
    }
  end

  @doc """
  Creates the binary loop `↺(body, redo)` as the cyclic choice graph from the
  POWL 2.0 mapping.

  The optional `exit_node` is retained for source compatibility. When present,
  it denotes `body · (redo · body)* · exit`; the admitted representation is
  still a choice graph, never a separate loop semantic kind.
  """
  def loop(id, body, redo_node, exit_node \\ nil, metadata \\ %{}) do
    body_id = node_id(body)
    redo_id = node_id(redo_node)

    if is_nil(exit_node) do
      choice_graph(
        id,
        [body, redo_node],
        [
          {@choice_start, body_id},
          {body_id, @choice_end},
          {body_id, redo_id},
          {redo_id, body_id}
        ],
        Map.put_new(metadata, :derived_operator, :loop)
      )
    else
      exit_id = node_id(exit_node)

      choice_graph(
        id,
        [body, redo_node, exit_node],
        [
          {@choice_start, body_id},
          {body_id, redo_id},
          {redo_id, body_id},
          {body_id, exit_id},
          {exit_id, @choice_end}
        ],
        Map.put_new(metadata, :derived_operator, :loop_with_exit)
      )
    end
  end

  @doc "Constructs, normalizes, and validates a complete POWL 2.0 model."
  def new(root_or_nodes, opts \\ [])

  def new(%Node{} = root, opts) do
    nodes = collect_nodes(root, %{})
    new(nodes, Keyword.put(opts, :root, root.id))
  end

  def new(nodes, opts) when is_list(nodes) do
    with {:ok, node_map} <- normalize_node_list(nodes) do
      new(node_map, opts)
    end
  end

  def new(nodes, opts) when is_map(nodes) do
    with {:ok, normalized_nodes} <- normalize_node_map(nodes),
         {:ok, root} <- determine_root(normalized_nodes, Keyword.get(opts, :root)) do
      model = %__MODULE__{
        id: to_string(Keyword.get(opts, :id, "powl:#{root}")),
        root: root,
        nodes: normalized_nodes,
        metadata: Keyword.get(opts, :metadata, %{})
      }

      with :ok <- validate(model) do
        subject = Subject.new(:powl_model, to_canonical_map(model))
        {:ok, %{model | subject: subject}}
      end
    end
  end

  @doc """
  Validates recursive closure, strict partial orders, and choice-graph
  well-formedness. Choice-graph cycles are admitted; partial-order cycles are
  refused.
  """
  def validate(%__MODULE__{nodes: nodes, root: root}) do
    all_ids = Map.keys(nodes) |> MapSet.new()

    with true <- MapSet.member?(all_ids, root) || invalid_root(root, all_ids) do
      nodes
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.reduce_while(:ok, fn {id, node}, :ok ->
        case validate_node(id, node, all_ids) do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end
  end

  @doc """
  Materializes a bounded set of traces from `ℒ(model)`.

  Options:

    * `:max_traces` — result cap, default `200`.
    * `:max_choice_visits` — maximum visits to any child on a choice-graph path.
    * `:max_loop_iterations` — compatibility shorthand; `n` permits at most
      `n + 1` visits to each node in a cyclic loop-shaped graph.
  """
  def language(%__MODULE__{} = model, opts \\ []) do
    max_traces = Keyword.get(opts, :max_traces, 200)

    max_choice_visits =
      Keyword.get(
        opts,
        :max_choice_visits,
        max(1, Keyword.get(opts, :max_loop_iterations, 2) + 1)
      )

    traces =
      generate_language(model, model.root, max_choice_visits, max_traces)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.take(max_traces)

    {:ok, traces}
  end

  @doc "Bounded trace-membership check using the same explicit bounds as `language/2`."
  def accepts?(%__MODULE__{} = model, trace, opts \\ []) when is_list(trace) do
    opts =
      opts
      |> Keyword.put_new(:max_traces, 10_000)
      |> Keyword.put_new(:max_choice_visits, max(1, length(trace) + 1))

    with {:ok, lang} <- language(model, opts) do
      Enum.map(trace, &to_string/1) in lang
    end
  end

  @doc """
  Translates a validated POWL 2.0 model into a WF-net.

  Choice-graph edges become silent routing transitions. Partial-order
  dependencies become synchronization places so a child with several
  predecessors cannot start until all predecessor completions have arrived.
  """
  def to_workflow_net(%__MODULE__{} = model) do
    with :ok <- validate(model) do
      counter = :atomics.new(1, [])
      sub_net = compile_node_to_wf(model, model.root, counter)

      WorkflowNet.new(
        Map.values(sub_net.places),
        Map.values(sub_net.transitions),
        sub_net.arcs,
        id: "#{model.id}_wf",
        source_place: sub_net.source_place,
        sink_place: sub_net.sink_place
      )
    end
  end

  defp validate_node(_id, %Node{type: type}, _all_ids) when type in [:activity, :silent], do: :ok

  defp validate_node(id, %Node{type: :partial_order} = node, all_ids) do
    with :ok <- validate_children(id, node.children, all_ids, 2),
         :ok <- validate_relation_endpoints(id, node.children, node.edges),
         :ok <- validate_strict_partial_order(id, node.children, node.edges) do
      :ok
    end
  end

  defp validate_node(id, %Node{type: :choice} = node, all_ids) do
    with :ok <- validate_children(id, node.children, all_ids, 2),
         :ok <- validate_choice_graph(id, node.children, node.choice_graph) do
      :ok
    end
  end

  defp validate_node(id, %Node{type: other}, _all_ids) do
    {:error,
     Refusal.new(:unsupported_powl_node, "Unsupported POWL semantic node kind",
       details: %{node: id, type: other}
     )}
  end

  defp validate_children(id, children, all_ids, minimum) do
    missing = Enum.reject(children, &MapSet.member?(all_ids, &1))

    cond do
      length(children) < minimum ->
        {:error,
         Refusal.new(:invalid_powl_arity, "POWL composite requires at least #{minimum} children",
           details: %{node: id, children: children}
         )}

      length(Enum.uniq(children)) != length(children) ->
        {:error,
         Refusal.new(:duplicate_powl_child, "POWL composite children must be distinct",
           details: %{node: id, children: children}
         )}

      missing != [] ->
        {:error,
         Refusal.new(:missing_child_node, "POWL node references missing children",
           details: %{node: id, missing: missing}
         )}

      true ->
        :ok
    end
  end

  defp validate_relation_endpoints(id, children, edges) do
    child_set = MapSet.new(children)

    invalid =
      Enum.reject(edges, fn {from, to} ->
        MapSet.member?(child_set, from) and MapSet.member?(child_set, to)
      end)

    if invalid == [] do
      :ok
    else
      {:error,
       Refusal.new(:invalid_partial_order, "Partial-order relation references a non-child",
         details: %{node: id, invalid_edges: invalid}
       )}
    end
  end

  defp validate_strict_partial_order(id, children, edges) do
    relation = MapSet.new(edges)
    closure = MapSet.new(transitive_closure(edges))

    cond do
      Enum.any?(edges, fn {from, to} -> from == to end) ->
        {:error,
         Refusal.new(:cyclic_powl_node, "POWL partial order is not irreflexive",
           details: %{node: id}
         )}

      relation != closure ->
        {:error,
         Refusal.new(:invalid_partial_order, "Stored POWL relation is not transitively closed",
           details: %{node: id}
         )}

      check_acyclic(children, edges) != :ok ->
        {:error,
         Refusal.new(:cyclic_powl_node, "POWL partial order contains a cycle",
           details: %{node: id}
         )}

      true ->
        :ok
    end
  end

  defp validate_choice_graph(id, children, %{nodes: graph_nodes, edges: edges}) do
    expected_children = MapSet.new(children)
    graph_children = MapSet.new(graph_nodes)
    allowed = MapSet.union(expected_children, MapSet.new([@choice_start, @choice_end]))

    invalid_edges =
      Enum.reject(edges, fn {from, to} ->
        MapSet.member?(allowed, from) and MapSet.member?(allowed, to)
      end)

    indegree = degree_map(allowed, edges, :in)
    outdegree = degree_map(allowed, edges, :out)

    sources =
      allowed
      |> Enum.filter(&(Map.get(indegree, &1, 0) == 0))
      |> Enum.sort()

    sinks =
      allowed
      |> Enum.filter(&(Map.get(outdegree, &1, 0) == 0))
      |> Enum.sort()

    reachable = reachable_from(@choice_start, edges)
    co_reachable = reachable_from(@choice_end, Enum.map(edges, fn {a, b} -> {b, a} end))

    cond do
      expected_children != graph_children ->
        invalid_choice_graph(id, :node_set_mismatch, %{
          expected: Enum.sort(children),
          graph_nodes: Enum.sort(graph_nodes)
        })

      invalid_edges != [] ->
        invalid_choice_graph(id, :unknown_endpoint, %{invalid_edges: invalid_edges})

      Enum.any?(edges, fn {_from, to} -> to == @choice_start end) ->
        invalid_choice_graph(id, :incoming_start_edge, %{})

      Enum.any?(edges, fn {from, _to} -> from == @choice_end end) ->
        invalid_choice_graph(id, :outgoing_end_edge, %{})

      sources != [@choice_start] ->
        invalid_choice_graph(id, :non_unique_start, %{sources: sources})

      sinks != [@choice_end] ->
        invalid_choice_graph(id, :non_unique_end, %{sinks: sinks})

      not MapSet.subset?(allowed, reachable) ->
        invalid_choice_graph(id, :unreachable_from_start, %{
          unreachable: allowed |> MapSet.difference(reachable) |> Enum.sort()
        })

      not MapSet.subset?(allowed, co_reachable) ->
        invalid_choice_graph(id, :cannot_reach_end, %{
          stranded: allowed |> MapSet.difference(co_reachable) |> Enum.sort()
        })

      true ->
        :ok
    end
  end

  defp validate_choice_graph(id, _children, other) do
    invalid_choice_graph(id, :malformed_graph, %{graph: other})
  end

  defp invalid_choice_graph(id, reason, details) do
    {:error,
     Refusal.new(:invalid_choice_graph, "Choice graph violates POWL 2.0 well-formedness",
       details: Map.merge(%{node: id, reason: reason}, details)
     )}
  end

  defp invalid_root(root, all_ids) do
    {:error,
     Refusal.new(:invalid_powl_root, "POWL root is not part of the admitted node set",
       details: %{root: root, available_nodes: Enum.sort(all_ids)}
     )}
  end

  defp generate_language(model, node_id, max_choice_visits, max_traces) do
    node = Map.fetch!(model.nodes, node_id)

    case node.type do
      :activity ->
        [[node.label || node.id]]

      :silent ->
        [[]]

      :choice ->
        node.choice_graph.edges
        |> choice_paths(max_choice_visits)
        |> Enum.flat_map(fn path ->
          Enum.reduce(path, [[]], fn child_id, acc ->
            child_traces = generate_language(model, child_id, max_choice_visits, max_traces)
            limited_cartesian_concat(acc, child_traces, max_traces)
          end)
        end)
        |> Enum.uniq()
        |> Enum.take(max_traces)

      :partial_order ->
        generate_po_language(model, node, max_choice_visits, max_traces)
    end
  end

  defp choice_paths(edges, max_visits) do
    successors =
      edges
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {node, targets} -> {node, Enum.sort(Enum.uniq(targets))} end)

    walk_choice(@choice_start, successors, %{}, [], max_visits)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp walk_choice(current, successors, visits, path, max_visits) do
    current
    |> then(&Map.get(successors, &1, []))
    |> Enum.flat_map(fn
      @choice_end ->
        [Enum.reverse(path)]

      next ->
        count = Map.get(visits, next, 0)

        if count < max_visits do
          walk_choice(
            next,
            successors,
            Map.put(visits, next, count + 1),
            [next | path],
            max_visits
          )
        else
          []
        end
    end)
  end

  defp generate_po_language(model, node, max_choice_visits, max_traces) do
    choices =
      node.children
      |> Enum.map(fn child ->
        {child, generate_language(model, child, max_choice_visits, max_traces)}
      end)

    trace_assignments(choices, max_traces)
    |> Enum.flat_map(fn selected ->
      order_preserving_shuffles(node.children, node.edges, selected, max_traces)
    end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.take(max_traces)
  end

  defp trace_assignments(child_languages, limit) do
    Enum.reduce(child_languages, [%{}], fn {child, traces}, assignments ->
      for assignment <- assignments,
          trace <- traces,
          reduce: [] do
        acc ->
          if length(acc) < limit do
            [Map.put(assignment, child, trace) | acc]
          else
            acc
          end
      end
      |> Enum.reverse()
      |> Enum.take(limit)
    end)
  end

  defp order_preserving_shuffles(children, edges, selected, limit) do
    predecessors =
      Map.new(children, fn child ->
        preds =
          edges
          |> Enum.filter(fn {_from, to} -> to == child end)
          |> Enum.map(&elem(&1, 0))
          |> MapSet.new()

        {child, preds}
      end)

    positions = Map.new(children, &{&1, 0})
    shuffle_step(children, predecessors, selected, positions, [], limit)
  end

  defp shuffle_step(children, predecessors, selected, positions, reversed_trace, limit) do
    if Enum.all?(children, &trace_complete?(&1, selected, positions)) do
      [Enum.reverse(reversed_trace)]
    else
      enabled =
        Enum.filter(children, fn child ->
          not trace_complete?(child, selected, positions) and
            Enum.all?(Map.fetch!(predecessors, child), fn pred ->
              trace_complete?(pred, selected, positions)
            end)
        end)

      enabled
      |> Enum.reduce_while([], fn child, acc ->
        if length(acc) >= limit do
          {:halt, acc}
        else
          pos = Map.fetch!(positions, child)
          event = selected |> Map.fetch!(child) |> Enum.at(pos)
          next_positions = Map.update!(positions, child, &(&1 + 1))

          traces =
            shuffle_step(
              children,
              predecessors,
              selected,
              next_positions,
              [event | reversed_trace],
              limit - length(acc)
            )

          {:cont, acc ++ traces}
        end
      end)
      |> Enum.take(limit)
    end
  end

  defp trace_complete?(child, selected, positions) do
    Map.fetch!(positions, child) >= length(Map.fetch!(selected, child))
  end

  defp limited_cartesian_concat(left, right, limit) do
    for l <- left, r <- right, reduce: [] do
      acc ->
        if length(acc) < limit, do: [l ++ r | acc], else: acc
    end
    |> Enum.reverse()
    |> Enum.take(limit)
  end

  defp compile_node_to_wf(model, node_id, counter) do
    node = Map.fetch!(model.nodes, node_id)

    case node.type do
      :activity -> compile_activity(node, counter)
      :silent -> compile_silent(counter)
      :choice -> compile_choice(model, node, counter)
      :partial_order -> compile_partial_order(model, node, counter)
    end
  end

  defp compile_activity(node, counter) do
    p_in = gen_id("p_in", counter)
    p_out = gen_id("p_out", counter)
    t_id = gen_id("t_act_#{node.id}", counter)

    %{
      places: %{p_in => %Place{id: p_in}, p_out => %Place{id: p_out}},
      transitions: %{
        t_id => %Transition{id: t_id, label: node.label || node.id, silent?: false}
      },
      arcs: [%Arc{source: p_in, target: t_id}, %Arc{source: t_id, target: p_out}],
      source_place: p_in,
      sink_place: p_out
    }
  end

  defp compile_silent(counter) do
    p_in = gen_id("p_in", counter)
    p_out = gen_id("p_out", counter)
    t_id = gen_id("t_tau", counter)

    %{
      places: %{p_in => %Place{id: p_in}, p_out => %Place{id: p_out}},
      transitions: %{t_id => %Transition{id: t_id, silent?: true}},
      arcs: [%Arc{source: p_in, target: t_id}, %Arc{source: t_id, target: p_out}],
      source_place: p_in,
      sink_place: p_out
    }
  end

  defp compile_choice(model, node, counter) do
    p_in = gen_id("p_choice_in", counter)
    p_out = gen_id("p_choice_out", counter)

    child_nets =
      Map.new(node.children, fn child ->
        {child, compile_node_to_wf(model, child, counter)}
      end)

    base = %{
      places: %{p_in => %Place{id: p_in}, p_out => %Place{id: p_out}},
      transitions: %{},
      arcs: []
    }

    merged =
      Enum.reduce(child_nets, base, fn {_id, net}, acc ->
        %{
          places: Map.merge(acc.places, net.places),
          transitions: Map.merge(acc.transitions, net.transitions),
          arcs: acc.arcs ++ net.arcs
        }
      end)

    {routing_transitions, routing_arcs} =
      Enum.reduce(node.choice_graph.edges, {%{}, []}, fn {from, to}, {transitions, arcs} ->
        t_id = gen_id("t_tau_choice", counter)
        source = choice_endpoint_place(from, :source, p_in, p_out, child_nets)
        target = choice_endpoint_place(to, :target, p_in, p_out, child_nets)

        {
          Map.put(transitions, t_id, %Transition{id: t_id, silent?: true}),
          arcs ++ [%Arc{source: source, target: t_id}, %Arc{source: t_id, target: target}]
        }
      end)

    %{
      places: merged.places,
      transitions: Map.merge(merged.transitions, routing_transitions),
      arcs: merged.arcs ++ routing_arcs,
      source_place: p_in,
      sink_place: p_out
    }
  end

  defp choice_endpoint_place(@choice_start, _direction, p_in, _p_out, _nets), do: p_in
  defp choice_endpoint_place(@choice_end, _direction, _p_in, p_out, _nets), do: p_out

  defp choice_endpoint_place(child, :source, _p_in, _p_out, nets),
    do: Map.fetch!(nets, child).sink_place

  defp choice_endpoint_place(child, :target, _p_in, _p_out, nets),
    do: Map.fetch!(nets, child).source_place

  defp compile_partial_order(model, node, counter) do
    p_in = gen_id("p_po_in", counter)
    p_out = gen_id("p_po_out", counter)

    child_nets =
      Map.new(node.children, fn child ->
        {child, compile_node_to_wf(model, child, counter)}
      end)

    relation = node.edges

    incoming =
      Map.new(node.children, fn child ->
        {child, Enum.filter(relation, fn {_from, to} -> to == child end)}
      end)

    outgoing =
      Map.new(node.children, fn child ->
        {child, Enum.filter(relation, fn {from, _to} -> from == child end)}
      end)

    dependency_places =
      Map.new(relation, fn {from, to} ->
        id = gen_id("p_dep_#{from}_#{to}", counter)
        {{from, to}, id}
      end)

    minimal = Enum.filter(node.children, &(Map.fetch!(incoming, &1) == []))
    maximal = Enum.filter(node.children, &(Map.fetch!(outgoing, &1) == []))

    init_places = Map.new(minimal, fn child -> {child, gen_id("p_init_#{child}", counter)} end)
    finish_places = Map.new(maximal, fn child -> {child, gen_id("p_finish_#{child}", counter)} end)

    base_places =
      %{p_in => %Place{id: p_in}, p_out => %Place{id: p_out}}
      |> put_named_places(Map.values(dependency_places))
      |> put_named_places(Map.values(init_places))
      |> put_named_places(Map.values(finish_places))

    merged =
      Enum.reduce(child_nets, %{places: base_places, transitions: %{}, arcs: []}, fn {_id, net},
                                                                                   acc ->
        %{
          places: Map.merge(acc.places, net.places),
          transitions: Map.merge(acc.transitions, net.transitions),
          arcs: acc.arcs ++ net.arcs
        }
      end)

    t_fork = gen_id("t_tau_po_fork", counter)
    t_join = gen_id("t_tau_po_join", counter)

    fork_arcs =
      [%Arc{source: p_in, target: t_fork}] ++
        Enum.map(minimal, fn child ->
          %Arc{source: t_fork, target: Map.fetch!(init_places, child)}
        end)

    join_arcs =
      Enum.map(maximal, fn child ->
        %Arc{source: Map.fetch!(finish_places, child), target: t_join}
      end) ++ [%Arc{source: t_join, target: p_out}]

    {control_transitions, control_arcs} =
      Enum.reduce(node.children, {%{}, []}, fn child, {transitions, arcs} ->
        t_start = gen_id("t_tau_po_start_#{child}", counter)
        t_done = gen_id("t_tau_po_done_#{child}", counter)
        net = Map.fetch!(child_nets, child)

        start_inputs =
          case Map.fetch!(incoming, child) do
            [] -> [Map.fetch!(init_places, child)]
            deps -> Enum.map(deps, &Map.fetch!(dependency_places, &1))
          end

        done_outputs =
          case Map.fetch!(outgoing, child) do
            [] -> [Map.fetch!(finish_places, child)]
            deps -> Enum.map(deps, &Map.fetch!(dependency_places, &1))
          end

        new_arcs =
          Enum.map(start_inputs, &%Arc{source: &1, target: t_start}) ++
            [%Arc{source: t_start, target: net.source_place}] ++
            [%Arc{source: net.sink_place, target: t_done}] ++
            Enum.map(done_outputs, &%Arc{source: t_done, target: &1})

        new_transitions =
          transitions
          |> Map.put(t_start, %Transition{id: t_start, silent?: true})
          |> Map.put(t_done, %Transition{id: t_done, silent?: true})

        {new_transitions, arcs ++ new_arcs}
      end)

    %{
      places: merged.places,
      transitions:
        merged.transitions
        |> Map.merge(control_transitions)
        |> Map.put(t_fork, %Transition{id: t_fork, silent?: true})
        |> Map.put(t_join, %Transition{id: t_join, silent?: true}),
      arcs: merged.arcs ++ fork_arcs ++ control_arcs ++ join_arcs,
      source_place: p_in,
      sink_place: p_out
    }
  end

  defp put_named_places(places, ids) do
    Enum.reduce(ids, places, fn id, acc -> Map.put(acc, id, %Place{id: id}) end)
  end

  defp determine_root(nodes, root_opt) do
    root =
      cond do
        not is_nil(root_opt) ->
          to_string(root_opt)

        map_size(nodes) == 1 ->
          nodes |> Map.keys() |> hd()

        true ->
          referenced =
            nodes
            |> Map.values()
            |> Enum.flat_map(&contained_children/1)
            |> MapSet.new()

          roots = Enum.reject(Map.keys(nodes), &MapSet.member?(referenced, &1))
          if length(roots) == 1, do: hd(roots), else: nil
      end

    if is_binary(root) and Map.has_key?(nodes, root) do
      {:ok, root}
    else
      {:error,
       Refusal.new(:invalid_powl_root, "Could not identify a unique POWL root",
         details: %{root: root, available_nodes: Map.keys(nodes)}
       )}
    end
  end

  defp normalize_node_list(nodes) do
    Enum.reduce_while(nodes, {:ok, %{}}, fn entry, {:ok, acc} ->
      case normalize_node_entry(entry) do
        {:ok, node} -> {:cont, {:ok, collect_nodes(node, acc)}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_node_map(nodes) do
    nodes
    |> Map.values()
    |> normalize_node_list()
    |> case do
      {:ok, normalized} ->
        {:ok, Map.new(normalized, fn {id, node} -> {id, normalize_legacy_node(node)} end)}

      error ->
        error
    end
  end

  defp normalize_node_entry(%Node{} = node), do: {:ok, normalize_legacy_node(node)}

  defp normalize_node_entry(map) when is_map(map) do
    id = get_field(map, :id)
    type = normalize_type(get_field(map, :type))

    if is_nil(id) or is_nil(type) do
      {:error,
       Refusal.new(:invalid_powl_node, "POWL node map requires id and type", subject: map)}
    else
      node =
        %Node{
          id: to_string(id),
          type: type,
          label: get_field(map, :label),
          children: Enum.map(get_field(map, :children) || [], &to_string/1),
          edges: normalize_relation_edges(get_field(map, :edges) || []),
          choice_graph: normalize_graph_map(get_field(map, :choice_graph)),
          loop_body: optional_id(get_field(map, :loop_body)),
          loop_redo: optional_id(get_field(map, :loop_redo)),
          loop_exit: optional_id(get_field(map, :loop_exit)),
          metadata: get_field(map, :metadata) || %{}
        }
        |> normalize_legacy_node()

      {:ok, node}
    end
  end

  defp normalize_node_entry(other) do
    {:error,
     Refusal.new(:invalid_powl_node, "POWL node must be a node struct or map", subject: other)}
  end

  defp normalize_legacy_node(%Node{type: :partial_order} = node) do
    %{node | edges: node.edges |> normalize_relation_edges() |> transitive_closure()}
  end

  defp normalize_legacy_node(%Node{type: :choice} = node) do
    graph =
      case node.choice_graph do
        %{nodes: nodes, edges: edges} ->
          normalized_nodes =
            case nodes do
              [] -> node.children
              nil -> node.children
              values -> values
            end

          %{nodes: Enum.map(normalized_nodes, &to_string/1), edges: normalize_choice_edges(edges)}

        _ ->
          %{nodes: node.children, edges: xor_edges(node.children)}
      end

    directed_graph? =
      Map.get(node.metadata, :choice_graph_semantics) == :directed_paths or
        Map.get(node.metadata, "choice_graph_semantics") in [:directed_paths, "directed_paths"]

    graph =
      if graph.edges == [] and node.children != [] and not directed_graph? do
        %{nodes: node.children, edges: xor_edges(node.children)}
      else
        graph
      end

    %{node | choice_graph: graph}
  end

  defp normalize_legacy_node(%Node{type: :loop} = node) do
    body = node.loop_body
    redo_node = node.loop_redo
    exit_node = node.loop_exit
    children = Enum.reject([body, redo_node, exit_node], &is_nil/1)

    edges =
      if is_nil(exit_node) do
        [
          {@choice_start, body},
          {body, @choice_end},
          {body, redo_node},
          {redo_node, body}
        ]
      else
        [
          {@choice_start, body},
          {body, redo_node},
          {redo_node, body},
          {body, exit_node},
          {exit_node, @choice_end}
        ]
      end

    %{
      node
      | type: :choice,
        children: children,
        choice_graph: %{nodes: children, edges: normalize_choice_edges(edges)},
        metadata: Map.put_new(node.metadata, :normalized_from, :legacy_loop)
    }
  end

  defp normalize_legacy_node(node), do: node

  defp collect_nodes(%Node{} = node, acc) do
    normalized = normalize_legacy_node(node)
    acc = Map.put(acc, normalized.id, %{normalized | embedded: %{}})

    Enum.reduce(node.embedded, acc, fn {_id, child}, nested_acc ->
      collect_nodes(child, nested_acc)
    end)
  end

  defp normalize_children(children) when is_list(children) do
    Enum.reduce(children, {[], %{}}, fn
      %Node{} = node, {ids, embedded} ->
        {ids ++ [node.id], Map.put(embedded, node.id, node)}

      id, {ids, embedded} ->
        {ids ++ [to_string(id)], embedded}
    end)
  end

  defp normalize_relation_edges(edges) when is_list(edges) do
    edges
    |> Enum.map(fn
      {from, to} -> {node_id(from), node_id(to)}
      [from, to] -> {node_id(from), node_id(to)}
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp normalize_choice_edges(edges), do: normalize_relation_edges(edges || [])

  defp normalize_graph_map(nil), do: %{nodes: [], edges: []}

  defp normalize_graph_map(graph) when is_map(graph) do
    %{
      nodes: Enum.map(get_field(graph, :nodes) || [], &to_string/1),
      edges: normalize_choice_edges(get_field(graph, :edges) || [])
    }
  end

  defp normalize_type(type) when type in [:activity, :silent, :partial_order, :choice, :loop], do: type

  defp normalize_type(type) when is_binary(type) do
    case type do
      "activity" -> :activity
      "silent" -> :silent
      "partial_order" -> :partial_order
      "choice" -> :choice
      "loop" -> :loop
      _ -> nil
    end
  end

  defp normalize_type(_), do: nil

  defp get_field(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp optional_id(nil), do: nil
  defp optional_id(value), do: to_string(value)

  defp contained_children(%Node{type: type, children: children})
       when type in [:partial_order, :choice],
       do: children

  defp contained_children(_), do: []

  defp xor_edges(children) do
    Enum.flat_map(children, fn child ->
      id = node_id(child)
      [{@choice_start, id}, {id, @choice_end}]
    end)
  end

  defp transitive_closure(edges) do
    relation = MapSet.new(edges)
    close_relation(relation)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp close_relation(relation) do
    inferred =
      for {a, b} <- relation,
          {c, d} <- relation,
          b == c,
          into: MapSet.new(),
          do: {a, d}

    next = MapSet.union(relation, inferred)
    if MapSet.equal?(next, relation), do: relation, else: close_relation(next)
  end

  defp check_acyclic(nodes, edges) do
    indegree =
      Enum.reduce(edges, Map.new(nodes, &{&1, 0}), fn {_from, to}, acc ->
        Map.update(acc, to, 1, &(&1 + 1))
      end)

    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    if consume_acyclic(indegree, successors, 0) == map_size(indegree) do
      :ok
    else
      :cyclic
    end
  end

  defp consume_acyclic(indegree, _successors, count) when map_size(indegree) == 0, do: count

  defp consume_acyclic(indegree, successors, count) do
    zeros =
      indegree
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(&elem(&1, 0))

    if zeros == [] do
      count
    else
      next =
        Enum.reduce(zeros, Map.drop(indegree, zeros), fn id, acc ->
          Enum.reduce(Map.get(successors, id, []), acc, fn successor, degrees ->
            Map.update!(degrees, successor, &(&1 - 1))
          end)
        end)

      consume_acyclic(next, successors, count + length(zeros))
    end
  end

  defp degree_map(nodes, edges, direction) do
    Enum.reduce(edges, Map.new(nodes, &{&1, 0}), fn {from, to}, acc ->
      key = if direction == :in, do: to, else: from
      Map.update(acc, key, 1, &(&1 + 1))
    end)
  end

  defp reachable_from(start, edges) do
    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))
    do_reachable([start], successors, MapSet.new())
  end

  defp do_reachable([], _successors, seen), do: seen

  defp do_reachable([node | rest], successors, seen) do
    if MapSet.member?(seen, node) do
      do_reachable(rest, successors, seen)
    else
      do_reachable(Map.get(successors, node, []) ++ rest, successors, MapSet.put(seen, node))
    end
  end

  defp gen_id(prefix, counter) do
    "#{prefix}_#{:atomics.add_get(counter, 1, 1)}"
  end

  defp node_id(%Node{id: id}), do: to_string(id)
  defp node_id(id) when is_binary(id) or is_atom(id), do: to_string(id)
  defp node_id(other), do: to_string(other)

  defp to_canonical_map(%__MODULE__{} = model) do
    %{
      id: model.id,
      root: model.root,
      nodes:
        Map.new(model.nodes, fn {id, node} ->
          {id, node |> Map.from_struct() |> Map.delete(:embedded)}
        end),
      metadata: model.metadata
    }
  end
end

defmodule Ex4pm.Engine.POWL do
  @moduledoc """
  Compatibility facade for `Ex4pmEngine.POWL`.

  The delegated implementation is the paper-aligned POWL 2.0 execution
  representation; this module adds no independent semantics.
  """

  defdelegate new(root_or_nodes, opts \\ []), to: Ex4pmEngine.POWL
  defdelegate activity(id, label \\ nil, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate silent(id, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate partial_order(id, children, edges \\ [], metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate concurrent(id, children, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate sequence(id, children, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate choice(id, children, opts \\ []), to: Ex4pmEngine.POWL
  defdelegate choice_graph(id, children, choice_edges, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate loop(id, body, redo_node, exit_node \\ nil, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate choice_start(), to: Ex4pmEngine.POWL
  defdelegate choice_end(), to: Ex4pmEngine.POWL
  defdelegate validate(model), to: Ex4pmEngine.POWL
  defdelegate language(model, opts \\ []), to: Ex4pmEngine.POWL
  defdelegate accepts?(model, trace, opts \\ []), to: Ex4pmEngine.POWL
  defdelegate to_workflow_net(model), to: Ex4pmEngine.POWL
end
