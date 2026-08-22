defmodule Ex4pmEngine.POWL.Node do
  @moduledoc "A node in a POWL 2.0 process tree."
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
    metadata: %{}
  ]

  @type node_type :: :activity | :silent | :partial_order | :choice | :loop
  @type t :: %__MODULE__{
          id: String.t(),
          type: node_type(),
          label: String.t() | nil,
          children: [String.t() | t()],
          edges: [{String.t(), String.t()}],
          choice_graph: %{nodes: [String.t()], edges: [{String.t(), String.t()}]},
          loop_body: String.t() | t() | nil,
          loop_redo: String.t() | t() | nil,
          loop_exit: String.t() | t() | nil,
          metadata: map()
        }
end

defmodule Ex4pmEngine.POWL do
  @moduledoc """
  POWL 2.0 (Partially Ordered Workflow Language) model with Generalized Choice Graphs
  and Language Preservation semantics.
  """

  alias Ex4pm.Refusal
  alias Ex4pm.Subject
  alias Ex4pmEngine.POWL.Node
  alias Ex4pmEngine.WorkflowNet
  alias Ex4pmEngine.WorkflowNet.{Arc, Place, Transition}

  @enforce_keys [:id, :root, :nodes]
  defstruct [
    :id,
    :root,
    :nodes,
    metadata: %{},
    subject: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          root: String.t(),
          nodes: %{optional(String.t()) => Node.t()},
          metadata: map(),
          subject: Subject.t() | nil
        }

  # Node constructors

  @doc "Creates an activity node."
  def activity(id, label \\ nil, metadata \\ %{}) do
    id_str = to_string(id)
    label_str = to_string(label || id_str)

    %Node{
      id: id_str,
      type: :activity,
      label: label_str,
      metadata: metadata
    }
  end

  @doc "Creates a silent/tau transition node."
  def silent(id, metadata \\ %{}) do
    %Node{
      id: to_string(id),
      type: :silent,
      metadata: metadata
    }
  end

  @doc "Creates a partial order node over child nodes."
  def partial_order(id, children, edges \\ [], metadata \\ %{}) do
    norm_children = Enum.map(children, &node_id/1)

    norm_edges =
      Enum.map(edges, fn
        {f, t} -> {node_id(f), node_id(t)}
        [f, t] -> {node_id(f), node_id(t)}
      end)

    %Node{
      id: to_string(id),
      type: :partial_order,
      children: norm_children,
      edges: norm_edges,
      metadata: metadata
    }
  end

  @doc "Creates a choice node (XOR choice or generalized choice graph)."
  def choice(id, children, opts \\ []) do
    norm_children = Enum.map(children, &node_id/1)
    choice_edges = Keyword.get(opts, :choice_edges, [])
    metadata = Keyword.get(opts, :metadata, %{})

    norm_choice_edges =
      Enum.map(choice_edges, fn
        {f, t} -> {node_id(f), node_id(t)}
        [f, t] -> {node_id(f), node_id(t)}
      end)

    %Node{
      id: to_string(id),
      type: :choice,
      children: norm_children,
      choice_graph: %{nodes: norm_children, edges: norm_choice_edges},
      metadata: metadata
    }
  end

  @doc "Creates a generalized choice graph node where edges represent branch conflict/exclusivity."
  def choice_graph(id, children, choice_edges, metadata \\ %{}) do
    choice(id, children, choice_edges: choice_edges, metadata: metadata)
  end

  @doc "Creates a loop node with body, redo, and optional exit."
  def loop(id, body, redo_node, exit_node \\ nil, metadata \\ %{}) do
    %Node{
      id: to_string(id),
      type: :loop,
      loop_body: node_id(body),
      loop_redo: node_id(redo_node),
      loop_exit: if(exit_node, do: node_id(exit_node), else: nil),
      children:
        Enum.reject(
          [node_id(body), node_id(redo_node), if(exit_node, do: node_id(exit_node), else: nil)],
          &is_nil/1
        ),
      metadata: metadata
    }
  end

  # Model constructor

  @doc "Constructs and validates a full POWL 2.0 model."
  def new(root_or_nodes, opts \\ [])

  def new(%Node{} = root, opts) do
    all_nodes = collect_nodes(root, %{})
    new(all_nodes, Keyword.put(opts, :root, root.id))
  end

  def new(nodes, opts) when is_list(nodes) do
    node_map =
      nodes
      |> Enum.map(fn
        %Node{} = n ->
          {n.id, n}

        map when is_map(map) ->
          id = Map.get(map, :id) || Map.get(map, "id")

          {to_string(id),
           struct(
             Node,
             Map.new(map, fn {k, v} ->
               {if(is_binary(k), do: String.to_existing_atom(k), else: k), v}
             end)
           )}
      end)
      |> Map.new()

    new(node_map, opts)
  end

  def new(nodes, opts) when is_map(nodes) do
    id = Keyword.get(opts, :id, "powl_#{System.unique_integer([:positive])}")
    metadata = Keyword.get(opts, :metadata, %{})
    root_opt = Keyword.get(opts, :root)

    root =
      cond do
        root_opt ->
          to_string(root_opt)

        map_size(nodes) == 1 ->
          hd(Map.keys(nodes))

        true ->
          # Root is the node that is not a child of any other node
          all_children =
            nodes
            |> Map.values()
            |> Enum.flat_map(fn n ->
              case n.type do
                :partial_order -> n.children
                :choice -> n.children
                :loop -> Enum.reject([n.loop_body, n.loop_redo, n.loop_exit], &is_nil/1)
                _ -> []
              end
            end)
            |> MapSet.new()

          roots = Enum.reject(Map.keys(nodes), &MapSet.member?(all_children, &1))
          if length(roots) == 1, do: hd(roots), else: nil
      end

    if is_nil(root) or not Map.has_key?(nodes, root) do
      {:error,
       Refusal.new(:invalid_powl_root, "Could not identify unique root node for POWL model",
         details: %{root: root, available_nodes: Map.keys(nodes)}
       )}
    else
      model = %__MODULE__{
        id: to_string(id),
        root: root,
        nodes: nodes,
        metadata: metadata
      }

      with :ok <- validate(model) do
        subject = Subject.new(:powl_model, to_canonical_map(model))
        {:ok, %{model | subject: subject}}
      end
    end
  end

  @doc "Validates POWL model acyclicity in partial orders and referential closure."
  def validate(%__MODULE__{nodes: nodes}) do
    all_node_ids = Map.keys(nodes) |> MapSet.new()

    Enum.reduce_while(nodes, :ok, fn {node_id, node}, :ok ->
      case node.type do
        :partial_order ->
          missing_children = Enum.reject(node.children, &MapSet.member?(all_node_ids, &1))

          if missing_children != [] do
            {:halt,
             {:error,
              Refusal.new(:missing_child_node, "POWL node references missing children",
                details: %{node: node_id, missing: missing_children}
              )}}
          else
            case check_acyclic(node.children, node.edges) do
              :ok -> {:cont, :ok}
              {:error, _} = err -> {:halt, err}
            end
          end

        :choice ->
          missing_children = Enum.reject(node.children, &MapSet.member?(all_node_ids, &1))

          if missing_children != [] do
            {:halt,
             {:error,
              Refusal.new(:missing_child_node, "POWL choice references missing children",
                details: %{node: node_id, missing: missing_children}
              )}}
          else
            {:cont, :ok}
          end

        :loop ->
          body = node.loop_body
          redo_n = node.loop_redo
          exit_n = node.loop_exit

          cond do
            not MapSet.member?(all_node_ids, body) ->
              {:halt,
               {:error,
                Refusal.new(:missing_child_node, "POWL loop body missing",
                  details: %{node: node_id, body: body}
                )}}

            not MapSet.member?(all_node_ids, redo_n) ->
              {:halt,
               {:error,
                Refusal.new(:missing_child_node, "POWL loop redo missing",
                  details: %{node: node_id, redo: redo_n}
                )}}

            exit_n != nil and not MapSet.member?(all_node_ids, exit_n) ->
              {:halt,
               {:error,
                Refusal.new(:missing_child_node, "POWL loop exit missing",
                  details: %{node: node_id, exit: exit_n}
                )}}

            true ->
              {:cont, :ok}
          end

        _ ->
          {:cont, :ok}
      end
    end)
  end

  # Language Preservation & Execution Semantics

  @doc """
  Computes the admitted language L(M) of the POWL model up to max_loop_iterations.
  Preserves language equivalence across representations.
  """
  def language(%__MODULE__{} = model, opts \\ []) do
    max_loops = Keyword.get(opts, :max_loop_iterations, 2)
    max_traces = Keyword.get(opts, :max_traces, 200)

    traces = generate_language(model, model.root, max_loops)
    bounded_traces = traces |> Enum.uniq() |> Enum.sort() |> Enum.take(max_traces)
    {:ok, bounded_traces}
  end

  @doc "Checks if a given trace of activity labels is accepted by the POWL model."
  def accepts?(%__MODULE__{} = model, trace) when is_list(trace) do
    with {:ok, lang} <- language(model, max_loop_iterations: 3, max_traces: 1000) do
      trace_strings = Enum.map(trace, &to_string/1)
      trace_strings in lang
    end
  end

  @doc "Translates a POWL 2.0 model into a standard sound 1-safe WorkflowNet."
  def to_workflow_net(%__MODULE__{} = model) do
    counter = :atomics.new(1, [])
    {sub_net, _} = compile_node_to_wf(model, model.root, counter)

    WorkflowNet.new(
      Map.values(sub_net.places),
      Map.values(sub_net.transitions),
      sub_net.arcs,
      id: "#{model.id}_wf",
      source_place: sub_net.source_place,
      sink_place: sub_net.sink_place
    )
  end

  # Language generation recursion

  defp generate_language(model, node_id, max_loops) do
    node = Map.fetch!(model.nodes, node_id)

    case node.type do
      :activity ->
        [[node.label || node.id]]

      :silent ->
        [[]]

      :choice ->
        Enum.flat_map(node.children, fn child_id ->
          generate_language(model, child_id, max_loops)
        end)

      :partial_order ->
        generate_po_language(model, node.children, node.edges, max_loops)

      :loop ->
        body_traces = generate_language(model, node.loop_body, max_loops)
        redo_traces = generate_language(model, node.loop_redo, max_loops)

        exit_traces =
          if node.loop_exit, do: generate_language(model, node.loop_exit, max_loops), else: [[]]

        # 0 iterations (just body then exit)
        iter0 = cartesian_concat(body_traces, exit_traces)

        # 1 to max_loops iterations
        Enum.reduce(1..max_loops, iter0, fn iter, acc ->
          iter_n =
            Enum.reduce(1..iter, body_traces, fn _i, current_body ->
              current_body
              |> cartesian_concat(redo_traces)
              |> cartesian_concat(body_traces)
            end)
            |> cartesian_concat(exit_traces)

          acc ++ iter_n
        end)
    end
  end

  defp generate_po_language(model, children, edges, max_loops) do
    # For each child, generate its possible sub-traces
    child_subtraces =
      Map.new(children, fn c_id ->
        {c_id, generate_language(model, c_id, max_loops)}
      end)

    # Interleave child tasks respecting DAG partial order
    po_orderings = generate_topological_sorts(children, edges)

    Enum.flat_map(po_orderings, fn ordering ->
      # For this linear sequence of child IDs, concatenate their sub-traces
      Enum.reduce(ordering, [[]], fn child_id, acc_traces ->
        subtraces = Map.get(child_subtraces, child_id, [[]])
        cartesian_concat(acc_traces, subtraces)
      end)
    end)
    |> Enum.uniq()
  end

  defp generate_topological_sorts(nodes, edges) do
    indegree =
      Enum.reduce(edges, Map.new(nodes, fn id -> {id, 0} end), fn {_from, to}, acc ->
        Map.update(acc, to, 1, &(&1 + 1))
      end)

    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    do_all_topological_sorts(nodes, indegree, successors, [], [])
  end

  defp do_all_topological_sorts(_nodes, indegree, _successors, current_order, all_orders)
       when map_size(indegree) == 0 do
    [Enum.reverse(current_order) | all_orders]
  end

  defp do_all_topological_sorts(nodes, indegree, successors, current_order, all_orders) do
    zeros =
      indegree
      |> Enum.filter(fn {_id, deg} -> deg == 0 end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    Enum.reduce(zeros, all_orders, fn next_node, acc ->
      next_indegree =
        Map.drop(indegree, [next_node])
        |> then(fn d ->
          Enum.reduce(Map.get(successors, next_node, []), d, fn succ, degs ->
            Map.update(degs, succ, 0, &(&1 - 1))
          end)
        end)

      do_all_topological_sorts(nodes, next_indegree, successors, [next_node | current_order], acc)
    end)
  end

  defp cartesian_concat(left_list, right_list) do
    for left <- left_list, right <- right_list, do: left ++ right
  end

  # Conversion to WorkflowNet

  defp compile_node_to_wf(model, node_id, counter) do
    node = Map.fetch!(model.nodes, node_id)

    case node.type do
      :activity ->
        p_in = gen_id("p_in", counter)
        p_out = gen_id("p_out", counter)
        t_id = gen_id("t_act_#{node.label || node.id}", counter)

        places = %{p_in => %Place{id: p_in}, p_out => %Place{id: p_out}}

        transitions = %{
          t_id => %Transition{id: t_id, label: node.label || node.id, silent?: false}
        }

        arcs = [%Arc{source: p_in, target: t_id}, %Arc{source: t_id, target: p_out}]

        {%{
           places: places,
           transitions: transitions,
           arcs: arcs,
           source_place: p_in,
           sink_place: p_out
         }, counter}

      :silent ->
        p_in = gen_id("p_in", counter)
        p_out = gen_id("p_out", counter)
        t_id = gen_id("t_tau", counter)

        places = %{p_in => %Place{id: p_in}, p_out => %Place{id: p_out}}
        transitions = %{t_id => %Transition{id: t_id, silent?: true}}
        arcs = [%Arc{source: p_in, target: t_id}, %Arc{source: t_id, target: p_out}]

        {%{
           places: places,
           transitions: transitions,
           arcs: arcs,
           source_place: p_in,
           sink_place: p_out
         }, counter}

      :choice ->
        p_in = gen_id("p_choice_in", counter)
        p_out = gen_id("p_choice_out", counter)

        {child_nets, _} =
          Enum.reduce(node.children, {[], counter}, fn c_id, {acc_nets, cnt} ->
            {c_net, updated_cnt} = compile_node_to_wf(model, c_id, cnt)
            {[c_net | acc_nets], updated_cnt}
          end)

        merged_places =
          Enum.reduce(child_nets, %{p_in => %Place{id: p_in}, p_out => %Place{id: p_out}}, fn cn,
                                                                                              acc ->
            Map.merge(acc, cn.places)
          end)

        merged_transitions =
          Enum.reduce(child_nets, %{}, fn cn, acc ->
            Map.merge(acc, cn.transitions)
          end)

        # Silent transitions connecting p_in to each child source, and each child sink to p_out
        {tau_transitions, connector_arcs, _} =
          Enum.reduce(child_nets, {%{}, [], counter}, fn cn, {t_acc, a_acc, cnt} ->
            t_split = gen_id("t_tau_choice_split", cnt)
            t_join = gen_id("t_tau_choice_join", cnt)

            new_t = %{
              t_split => %Transition{id: t_split, silent?: true},
              t_join => %Transition{id: t_join, silent?: true}
            }

            new_a = [
              %Arc{source: p_in, target: t_split},
              %Arc{source: t_split, target: cn.source_place},
              %Arc{source: cn.sink_place, target: t_join},
              %Arc{source: t_join, target: p_out}
            ]

            {Map.merge(t_acc, new_t), a_acc ++ new_a, cnt}
          end)

        all_arcs = Enum.flat_map(child_nets, & &1.arcs) ++ connector_arcs

        {%{
           places: merged_places,
           transitions: Map.merge(merged_transitions, tau_transitions),
           arcs: all_arcs,
           source_place: p_in,
           sink_place: p_out
         }, counter}

      :partial_order ->
        p_in = gen_id("p_po_in", counter)
        p_out = gen_id("p_po_out", counter)

        # Compile all children
        child_nets_map =
          Map.new(node.children, fn c_id ->
            {c_net, _} = compile_node_to_wf(model, c_id, counter)
            {c_id, c_net}
          end)

        # Merged places and transitions
        merged_places =
          Enum.reduce(
            Map.values(child_nets_map),
            %{p_in => %Place{id: p_in}, p_out => %Place{id: p_out}},
            fn cn, acc ->
              Map.merge(acc, cn.places)
            end
          )

        merged_transitions =
          Enum.reduce(Map.values(child_nets_map), %{}, fn cn, acc ->
            Map.merge(acc, cn.transitions)
          end)

        # Topological sorting / edge synchronization
        # For each edge {u, v}, connect sink of u to source of v via a place or transition
        {edge_arcs, sync_transitions} =
          Enum.reduce(node.edges, {[], %{}}, fn {u_id, v_id}, {a_acc, t_acc} ->
            u_net = Map.fetch!(child_nets_map, u_id)
            v_net = Map.fetch!(child_nets_map, v_id)
            t_sync = gen_id("t_tau_sync", counter)

            arcs = [
              %Arc{source: u_net.sink_place, target: t_sync},
              %Arc{source: t_sync, target: v_net.source_place}
            ]

            {a_acc ++ arcs, Map.put(t_acc, t_sync, %Transition{id: t_sync, silent?: true})}
          end)

        # Fork from p_in to initial nodes (indegree 0 in DAG)
        indegree =
          Enum.reduce(node.edges, Map.new(node.children, fn id -> {id, 0} end), fn {_f, t}, acc ->
            Map.update(acc, t, 1, &(&1 + 1))
          end)

        starts = Enum.filter(node.children, fn id -> Map.get(indegree, id, 0) == 0 end)

        outdegree =
          Enum.reduce(node.edges, Map.new(node.children, fn id -> {id, 0} end), fn {f, _t}, acc ->
            Map.update(acc, f, 1, &(&1 + 1))
          end)

        ends = Enum.filter(node.children, fn id -> Map.get(outdegree, id, 0) == 0 end)

        t_fork = gen_id("t_tau_fork", counter)
        t_join = gen_id("t_tau_join", counter)

        fork_join_transitions = %{
          t_fork => %Transition{id: t_fork, silent?: true},
          t_join => %Transition{id: t_join, silent?: true}
        }

        fork_arcs =
          [%Arc{source: p_in, target: t_fork}] ++
            Enum.map(starts, fn s_id ->
              s_net = Map.fetch!(child_nets_map, s_id)
              %Arc{source: t_fork, target: s_net.source_place}
            end)

        join_arcs =
          Enum.map(ends, fn e_id ->
            e_net = Map.fetch!(child_nets_map, e_id)
            %Arc{source: e_net.sink_place, target: t_join}
          end) ++ [%Arc{source: t_join, target: p_out}]

        all_arcs =
          Enum.flat_map(Map.values(child_nets_map), & &1.arcs) ++
            edge_arcs ++ fork_arcs ++ join_arcs

        all_transitions =
          merged_transitions
          |> Map.merge(sync_transitions)
          |> Map.merge(fork_join_transitions)

        {%{
           places: merged_places,
           transitions: all_transitions,
           arcs: all_arcs,
           source_place: p_in,
           sink_place: p_out
         }, counter}

      :loop ->
        p_in = gen_id("p_loop_in", counter)
        p_out = gen_id("p_loop_out", counter)

        {body_net, _} = compile_node_to_wf(model, node.loop_body, counter)
        {redo_net, _} = compile_node_to_wf(model, node.loop_redo, counter)

        t_enter = gen_id("t_tau_loop_enter", counter)
        t_redo_join = gen_id("t_tau_redo_join", counter)
        t_exit = gen_id("t_tau_loop_exit", counter)

        transitions =
          Map.merge(body_net.transitions, redo_net.transitions)
          |> Map.put(t_enter, %Transition{id: t_enter, silent?: true})
          |> Map.put(t_redo_join, %Transition{id: t_redo_join, silent?: true})
          |> Map.put(t_exit, %Transition{id: t_exit, silent?: true})

        places =
          Map.merge(body_net.places, redo_net.places)
          |> Map.put(p_in, %Place{id: p_in})
          |> Map.put(p_out, %Place{id: p_out})

        loop_arcs = [
          # Entry to body
          %Arc{source: p_in, target: t_enter},
          %Arc{source: t_enter, target: body_net.source_place},
          # Body to redo
          %Arc{source: body_net.sink_place, target: redo_net.source_place},
          # Redo back to body entry
          %Arc{source: redo_net.sink_place, target: t_redo_join},
          %Arc{source: t_redo_join, target: body_net.source_place},
          # Exit from body sink to p_out
          %Arc{source: body_net.sink_place, target: t_exit},
          %Arc{source: t_exit, target: p_out}
        ]

        all_arcs = body_net.arcs ++ redo_net.arcs ++ loop_arcs

        {%{
           places: places,
           transitions: transitions,
           arcs: all_arcs,
           source_place: p_in,
           sink_place: p_out
         }, counter}
    end
  end

  defp gen_id(prefix, counter) do
    val = :atomics.add_get(counter, 1, 1)
    "#{prefix}_#{val}"
  end

  defp check_acyclic(nodes, edges) do
    node_set =
      MapSet.new(nodes) |> MapSet.union(MapSet.new(Enum.flat_map(edges, fn {f, t} -> [f, t] end)))

    indegree =
      Enum.reduce(edges, Map.new(node_set, fn id -> {id, 0} end), fn {_from, to}, acc ->
        Map.update(acc, to, 1, &(&1 + 1))
      end)

    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    case consume_acyclic(indegree, successors, 0) do
      count when count == map_size(indegree) -> :ok
      _ -> {:error, Refusal.new(:cyclic_powl_node, "POWL node contains a cycle in partial order")}
    end
  end

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
            Map.update(degrees, successor, 0, &(&1 - 1))
          end)
        end)

      consume_acyclic(next, successors, count + length(zeros))
    end
  end

  defp collect_nodes(%Node{} = node, acc) do
    acc = Map.put(acc, node.id, node)
    acc
  end

  defp node_id(%Node{id: id}), do: to_string(id)
  defp node_id(id) when is_binary(id) or is_atom(id), do: to_string(id)
  defp node_id(other), do: to_string(other)

  defp to_canonical_map(%__MODULE__{} = model) do
    %{
      id: model.id,
      root: model.root,
      nodes: Map.new(model.nodes, fn {k, v} -> {k, Map.from_struct(v)} end),
      metadata: model.metadata
    }
  end
end

defmodule Ex4pm.Engine.POWL do
  @moduledoc "Alias module for Ex4pmEngine.POWL."
  defdelegate new(root_or_nodes, opts \\ []), to: Ex4pmEngine.POWL
  defdelegate activity(id, label \\ nil, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate silent(id, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate partial_order(id, children, edges \\ [], metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate choice(id, children, opts \\ []), to: Ex4pmEngine.POWL
  defdelegate choice_graph(id, children, choice_edges, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate loop(id, body, redo_node, exit_node \\ nil, metadata \\ %{}), to: Ex4pmEngine.POWL
  defdelegate validate(model), to: Ex4pmEngine.POWL
  defdelegate language(model, opts \\ []), to: Ex4pmEngine.POWL
  defdelegate accepts?(model, trace), to: Ex4pmEngine.POWL
  defdelegate to_workflow_net(model), to: Ex4pmEngine.POWL
end
