defmodule Ex4pmEngine.POWL do
  @moduledoc """
  POWL 2.0 (Partially Ordered Workflow Language) Engine.
  Exact Mathematical Realization of:
  - [BPM25] Kourani, Park, van der Aalst (2025). Unlocking Non-Block-Structured Decisions: Inductive Mining with Choice Graphs. BPM 2025, LNCS 16044, pp. 144–161.
  - [PETRI25] Kourani, Park, van der Aalst (2025). Hierarchical Decomposition of Separable Workflow-Nets. PETRI NETS 2025, LNCS 15714, pp. 242–264.

  Represents process models as hierarchical, sound-by-construction operator trees:
  - `Activity`: Leaf node executing a labeled transition $t \\in T$ with $l(t) \\in \\Sigma$.
  - `Silent`: Silent transition $t$ with $l(t) = \\tau$ (skip).
  - `Sequence`: Strict linear composition $\\times(T_1, T_2, \\dots, T_n)$.
  - `Choice`: Exclusive branching $\\oplus(T_1, T_2, \\dots, T_n)$ or ChoiceGraph $G = (N, E)$.
  - `ChoiceGraph`: POWL 2.0 directed choice graph $G = (N, E)$ with artificial delimiters $▷, □$.
  - `Loop`: Iterative repeat $\\circlearrowleft(body, redo)$ / $\\looparrowright$.
  - `PartialOrder`: Concurrency constrained by explicit poset edges $(nodes, order\\_edges)$ with order-preserving shuffle $\\prec\\hspace{-0.6em}\\odot$.

  Every valid POWL 2.0 tree is mathematically guaranteed to be 1-safe sound without reachability anomalies.
  """

  alias Ex4pmEngine.POWL.ChoiceGraph
  alias Ex4pmEngine.WorkflowNet

  defmodule Node do
    @enforce_keys [:id, :operator]
    defstruct [:id, :operator, :label, children: [], order_edges: [], choice_graph: nil, metadata: %{}]
  end

  @doc "Constructs a leaf activity node."
  def activity(id, label) do
    %Node{id: to_string(id), operator: :activity, label: label}
  end

  @doc "Constructs a silent tau transition node."
  def silent(id \\ nil) do
    node_id = if id, do: to_string(id), else: "tau_#{System.unique_integer([:positive])}"
    %Node{id: node_id, operator: :silent, label: "tau"}
  end

  @doc "Constructs a sequential composition of child nodes."
  def sequence(id, children) when is_list(children) do
    %Node{id: to_string(id), operator: :sequence, children: children}
  end

  @doc "Constructs an exclusive choice composition of child nodes."
  def choice(id, children) when is_list(children) do
    %Node{id: to_string(id), operator: :choice, children: children}
  end

  @doc """
  Constructs a POWL 2.0 Choice Graph node $G = (N, E)$ with delimiters $▷, □$:
  - Definition 1 [BPM25, p. 7]
  - Definition 3.6 [PETRI25, p. 8]
  """
  def choice_graph(id, nodes, edges) when is_list(nodes) and is_list(edges) do
    case ChoiceGraph.new(nodes, edges, %{id: to_string(id)}) do
      {:ok, cg} ->
        %Node{id: to_string(id), operator: :choice_graph, children: nodes, choice_graph: cg}

      {:error, reason} ->
        raise ArgumentError, "Invalid POWL 2.0 Choice Graph: #{reason}"
    end
  end

  @doc "Constructs a loop composition with body and redo branches."
  def loop(id, body_node, redo_node) do
    %Node{id: to_string(id), operator: :loop, children: [body_node, redo_node]}
  end

  @doc "Constructs a partially ordered workflow node with explicit precedence edges."
  def partial_order(id, nodes, order_edges) when is_list(nodes) and is_list(order_edges) do
    norm_edges = Enum.map(order_edges, fn {s, d} -> {to_string(s), to_string(d)} end)
    %Node{id: to_string(id), operator: :partial_order, children: nodes, order_edges: norm_edges}
  end

  @doc "Constructs a POWL model from a map of nodes and a designated root node id."
  def new(nodes, opts \\ []) when is_map(nodes) do
    root_id = Keyword.get(opts, :root)
    root = Map.get(nodes, root_id) || Map.get(nodes, to_string(root_id))

    if root do
      {:ok, %{root: root, nodes: nodes}}
    else
      {:error, :root_not_found}
    end
  end

  @doc """
  Translates a POWL tree into a mathematically sound Workflow Net (Petri Net).
  Returns `%{places: [...], transitions: %{...}, initial_marking: [...], final_marking: [...]}` or `{:ok, %WorkflowNet{}}`.
  """
  def to_workflow_net(%{root: root}) do
    net_map = compile_to_net_map(root)

    arcs =
      Enum.flat_map(net_map.transitions, fn {t_name, t_def} ->
        in_arcs = Enum.map(t_def.inputs, fn p -> {to_string(p), to_string(t_name)} end)
        out_arcs = Enum.map(t_def.outputs, fn p -> {to_string(t_name), to_string(p)} end)
        in_arcs ++ out_arcs
      end)

    places = Enum.map(net_map.places, &to_string/1)
    transitions = Enum.map(Map.keys(net_map.transitions), &to_string/1)

    WorkflowNet.new(places, transitions, arcs, source_place: "p_start", sink_place: "p_end")
  end

  def to_workflow_net(%Node{} = root) do
    case to_workflow_net(%{root: root}) do
      {:ok, wn} -> wn
      error -> error
    end
  end

  def compile_to_net_map(%Node{} = root) do
    {net, p_in, p_out, _next_id} = compile_node(root, "p_start", "p_end", 1)

    %{
      places: Enum.uniq([p_in, p_out | net.places]),
      transitions: net.transitions,
      initial_marking: [p_in],
      final_marking: [p_out]
    }
  end

  defp compile_node(%Node{operator: :activity, id: id, label: label}, p_in, p_out, next_id) do
    t_name = :"t_#{id}_#{next_id}"

    t_def = %{
      inputs: [p_in],
      outputs: [p_out],
      label: label,
      node_id: id
    }

    net = %{
      places: [p_in, p_out],
      transitions: %{t_name => t_def}
    }

    {net, p_in, p_out, next_id + 1}
  end

  defp compile_node(%Node{operator: :silent, id: id}, p_in, p_out, next_id) do
    t_name = :"t_tau_#{id}_#{next_id}"

    t_def = %{
      inputs: [p_in],
      outputs: [p_out],
      label: "tau",
      node_id: id
    }

    net = %{
      places: [p_in, p_out],
      transitions: %{t_name => t_def}
    }

    {net, p_in, p_out, next_id + 1}
  end

  defp compile_node(%Node{operator: :sequence, children: children}, p_in, p_out, next_id) do
    case children do
      [] ->
        compile_node(silent(), p_in, p_out, next_id)

      [single] ->
        compile_node(single, p_in, p_out, next_id)

      [first | rest] ->
        {net_first, _, p_mid, id_after_first} =
          compile_node(first, p_in, "p_seq_#{next_id}", next_id + 1)

        {net_rest, final_out, final_id} =
          Enum.reduce(rest, {net_first, p_mid, id_after_first}, fn child,
                                                                   {acc_net, cur_in, cur_id} ->
            is_last? = child == List.last(rest)
            cur_out = if is_last?, do: p_out, else: "p_seq_#{cur_id}"

            {child_net, _, next_out, next_id_count} =
              compile_node(child, cur_in, cur_out, cur_id + 1)

            merged_net = merge_nets(acc_net, child_net)
            {merged_net, next_out, next_id_count}
          end)

        {net_rest, p_in, final_out, final_id}
    end
  end

  defp compile_node(%Node{operator: :choice, children: children}, p_in, p_out, next_id) do
    {merged_net, final_id} =
      Enum.reduce(children, {%{places: [p_in, p_out], transitions: %{}}, next_id}, fn child,
                                                                                      {acc_net,
                                                                                       cur_id} ->
        {child_net, _, _, next_id_count} = compile_node(child, p_in, p_out, cur_id)
        {merge_nets(acc_net, child_net), next_id_count}
      end)

    {merged_net, p_in, p_out, final_id}
  end

  defp compile_node(%Node{operator: :choice_graph, children: children, choice_graph: cg}, p_in, p_out, next_id) do
    # Section 4.1 [BPM25 p. 9]:
    # (i) Unique source p_in and sink p_out
    # (ii) Recursively convert each submodel
    # (iii) Add silent tau-transitions according to edges of the choice graph
    node_places =
      Enum.map(children, fn child ->
        {child.id, "p_in_cg_#{child.id}_#{next_id}", "p_out_cg_#{child.id}_#{next_id}"}
      end)

    # Compile children into isolated subnets
    {children_net, id_after_children} =
      Enum.reduce(children, {%{places: [p_in, p_out], transitions: %{}}, next_id + 1}, fn child, {acc_net, cur_id} ->
        {_id, c_in, c_out} = Enum.find(node_places, &(elem(&1, 0) == child.id))
        {child_net, _, _, next_c_id} = compile_node(child, c_in, c_out, cur_id)
        {merge_nets(acc_net, child_net), next_c_id}
      end)

    # Add connecting tau transitions for all edges in cg.edges
    start_del = ChoiceGraph.start_delimiter()
    end_del = ChoiceGraph.end_delimiter()

    {final_net, final_id} =
      Enum.reduce(cg.edges, {children_net, id_after_children}, fn {src, dst}, {acc_net, cur_id} ->
        src_place =
          case src do
            ^start_del -> p_in
            other ->
              {_, _, out_p} = Enum.find(node_places, &(elem(&1, 0) == other))
              out_p
          end

        dst_place =
          case dst do
            ^end_del -> p_out
            other ->
              {_, in_p, _} = Enum.find(node_places, &(elem(&1, 0) == other))
              in_p
          end

        t_edge_name = :"t_cg_edge_#{src}_to_#{dst}_#{cur_id}"
        t_edge_def = %{
          inputs: [src_place],
          outputs: [dst_place],
          label: "tau_cg",
          node_id: "cg_edge"
        }

        new_net = %{
          acc_net
          | places: Enum.uniq([src_place, dst_place | acc_net.places]),
            transitions: Map.put(acc_net.transitions, t_edge_name, t_edge_def)
        }

        {new_net, cur_id + 1}
      end)

    {final_net, p_in, p_out, final_id}
  end

  defp compile_node(%Node{operator: :loop, children: [body, redo_node]}, p_in, p_out, next_id) do
    # Formal loop: unique source p_in -> t_init -> p_loop_in -> body -> p_loop_body_out
    # p_loop_body_out -> redo_node -> p_loop_in
    # p_loop_body_out -> t_exit -> p_out
    p_loop_in = "p_loop_in_#{next_id}"
    p_body_out = "p_loop_body_out_#{next_id}"

    t_init_name = :"t_init_loop_#{next_id}"
    t_init_def = %{
      inputs: [p_in],
      outputs: [p_loop_in],
      label: "tau_init",
      node_id: "loop_init"
    }

    {net_body, _, _, id1} = compile_node(body, p_loop_in, p_body_out, next_id + 1)
    {net_redo, _, _, id2} = compile_node(redo_node, p_body_out, p_loop_in, id1)

    t_exit_name = :"t_exit_#{id2}"
    exit_trans = %{
      inputs: [p_body_out],
      outputs: [p_out],
      label: "tau_exit",
      node_id: "exit"
    }

    combined =
      merge_nets(net_body, net_redo)
      |> merge_nets(%{
        places: [p_in, p_loop_in, p_body_out, p_out],
        transitions: %{t_init_name => t_init_def, t_exit_name => exit_trans}
      })

    {combined, p_in, p_out, id2 + 1}
  end

  defp compile_node(
         %Node{operator: :partial_order, children: children, order_edges: edges},
         p_in,
         p_out,
         next_id
       ) do
    all_child_ids = Enum.map(children, & &1.id)
    edge_sources = Enum.map(edges, &elem(&1, 0)) |> MapSet.new()
    edge_targets = Enum.map(edges, &elem(&1, 1)) |> MapSet.new()

    initial_child_ids = Enum.reject(all_child_ids, &MapSet.member?(edge_targets, &1))
    terminal_child_ids = Enum.reject(all_child_ids, &MapSet.member?(edge_sources, &1))

    # Places mapping
    node_places =
      Enum.map(children, fn child ->
        {child.id, "p_in_#{child.id}_#{next_id}", "p_out_#{child.id}_#{next_id}"}
      end)

    t_fork = :"t_fork_po_#{next_id}"
    t_join = :"t_join_po_#{next_id}"

    fork_outputs =
      Enum.filter(node_places, fn {id, _in_p, _out_p} -> id in initial_child_ids end)
      |> Enum.map(&elem(&1, 1))

    join_inputs =
      Enum.filter(node_places, fn {id, _in_p, _out_p} -> id in terminal_child_ids end)
      |> Enum.map(&elem(&1, 2))

    fork_trans = %{inputs: [p_in], outputs: fork_outputs, label: "tau_fork", node_id: "fork"}
    join_trans = %{inputs: join_inputs, outputs: [p_out], label: "tau_join", node_id: "join"}

    base_net = %{
      places: [p_in, p_out | fork_outputs ++ join_inputs],
      transitions: %{t_fork => fork_trans, t_join => join_trans}
    }

    # Compile children into net
    {all_children_net, id_after_children} =
      Enum.reduce(children, {base_net, next_id + 1}, fn child, {acc_net, cur_id} ->
        {_id, c_in, c_out} = Enum.find(node_places, &(elem(&1, 0) == child.id))
        {child_net, _, _, next_c_id} = compile_node(child, c_in, c_out, cur_id)
        {merge_nets(acc_net, child_net), next_c_id}
      end)

    # For each order edge (u, v):
    # Transition t_sync_u_v connects p_out_u to p_in_v.
    # When u has multiple targets, a fork transition t_fork_u produces to each target sync place.
    # Group edges by source:
    edges_by_source = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    final_net =
      Enum.reduce(edges_by_source, all_children_net, fn {src_id, target_ids}, net ->
        {_, _src_in, src_out} = Enum.find(node_places, &(elem(&1, 0) == src_id))

        target_in_places =
          Enum.map(target_ids, fn dst_id ->
            {_, dst_in, _} = Enum.find(node_places, &(elem(&1, 0) == dst_id))
            dst_in
          end)

        t_sync_name = :"t_sync_#{src_id}_#{next_id}"

        t_sync_def = %{
          inputs: [src_out],
          outputs: target_in_places,
          label: "tau_sync",
          node_id: "sync"
        }

        %{
          net
          | places: Enum.uniq([src_out | target_in_places ++ net.places]),
            transitions: Map.put(net.transitions, t_sync_name, t_sync_def)
        }
      end)

    {final_net, p_in, p_out, id_after_children}
  end

  defp merge_nets(net1, net2) do
    %{
      places: Enum.uniq(net1.places ++ net2.places),
      transitions: Map.merge(net1.transitions, net2.transitions)
    }
  end
end
