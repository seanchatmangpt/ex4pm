defmodule Ex4pmEngine.Cognition.Ocpq do
  @moduledoc """
  Object-Centric Process Querying & Constraints (OCPQ).
  Faithful, high-throughput BEAM realization of Küsters & van der Aalst (arXiv:2506.11541v1, 2025).

  Evaluates multi-object variable bindings across disjoint event and object universes:
  - `BindingBox`: quantified variable domains (Var, Pred)
  - `BasicPredicate`: E2O, O2O, and TBE (Time Between Events: <, <=, ==, >=, >)
  - `QueryTree`: hierarchical query trees with child cardinality bounds
  - `Constraint`: structural invariant satisfaction/violation over OCEL logs
  """

  alias Ex4pm.EventLog

  defmodule VarDecl do
    @enforce_keys [:name, :kind]
    defstruct [:name, :kind, types: []]
  end

  defmodule BasicPredicate do
    @type t ::
            {:e2o, event_var :: String.t(), object_var :: String.t(),
             qualifier :: String.t() | nil}
            | {:o2o, source_var :: String.t(), target_var :: String.t(),
               qualifier :: String.t() | nil}
            | {:tbe, ev_a :: String.t(), ev_b :: String.t(), op :: atom(),
               threshold_ms :: number()}
  end

  defmodule BindingBox do
    @enforce_keys [:vars, :predicates]
    defstruct [:vars, :predicates, metadata: %{}]
  end

  defmodule QueryTree do
    @enforce_keys [:root_box]
    defstruct [:root_box, children: [], min_children: 0, max_children: :infinity]
  end

  defmodule IndexContext do
    @moduledoc "O(1) lookup index built over an EventLog for high-speed query evaluation."
    defstruct [
      :event_map,
      :events_by_type,
      :objects_by_type,
      :e2o_set,
      :o2o_set,
      :o2o_by_source,
      :e2o_by_object,
      :time_map
    ]
  end

  @doc "Builds an IndexContext for fast repetitive querying over an EventLog."
  def build_index(%EventLog{} = log) do
    event_map = Map.new(log.events, &{&1.id, &1})
    events_by_type = Enum.group_by(log.events, & &1.activity, & &1.id)
    objects_by_type = Enum.group_by(Map.values(log.objects), & &1.type, & &1.id)

    e2o_list =
      Enum.flat_map(log.events, fn ev ->
        direct = Enum.map(ev.object_ids, fn obj_id -> {ev.id, obj_id, nil} end)

        rel =
          Enum.map(ev.relationships, fn r ->
            obj_id = Map.get(r, "objectId") || Map.get(r, "object_id") || Map.get(r, :object_id)
            qual = Map.get(r, "qualifier") || Map.get(r, :qualifier)
            {ev.id, obj_id, qual}
          end)

        direct ++ rel
      end)

    e2o_set = MapSet.new(e2o_list)
    e2o_by_object = Enum.group_by(e2o_list, &elem(&1, 1), &elem(&1, 0))

    o2o_list =
      Enum.map(log.object_relationships, fn r -> {r.source_id, r.target_id, r.qualifier} end)

    o2o_set = MapSet.new(o2o_list)
    o2o_by_source = Enum.group_by(o2o_list, &elem(&1, 0), fn {_s, t, q} -> {t, q} end)

    time_map =
      Map.new(log.events, fn ev ->
        case DateTime.from_iso8601(to_string(ev.timestamp)) do
          {:ok, dt, _} -> {ev.id, DateTime.to_unix(dt, :millisecond)}
          _ -> {ev.id, 0}
        end
      end)

    %IndexContext{
      event_map: event_map,
      events_by_type: events_by_type,
      objects_by_type: objects_by_type,
      e2o_set: e2o_set,
      o2o_set: o2o_set,
      o2o_by_source: o2o_by_source,
      e2o_by_object: e2o_by_object,
      time_map: time_map
    }
  end

  @doc "Evaluates an OCPQ QueryTree against an EventLog, checking whether all constraints hold."
  def evaluate_query(%EventLog{} = log, %QueryTree{} = tree) do
    ctx = build_index(log)
    evaluate_query_indexed(ctx, tree)
  end

  def evaluate_query_indexed(%IndexContext{} = ctx, %QueryTree{} = tree) do
    root_bindings = evaluate_box_indexed(ctx, tree.root_box)

    violations =
      Enum.flat_map(root_bindings, fn root_binding ->
        child_results =
          Enum.map(tree.children, fn child_tree ->
            eval_child_branch(ctx, child_tree, root_binding)
          end)

        violating_branches =
          Enum.filter(child_results, fn %{count: count, min: min, max: max} ->
            count < min or (max != :infinity and count > max)
          end)

        case violating_branches do
          [] -> []
          bad -> [{:cardinality_violation, root_binding, bad}]
        end
      end)

    %{
      satisfied?: violations == [],
      total_root_bindings: length(root_bindings),
      violations_count: length(violations),
      violations: violations
    }
  end

  @doc "Evaluates a single BindingBox against an EventLog or IndexContext."
  def evaluate_box(%EventLog{} = log, %BindingBox{} = box, parent_binding \\ %{}) do
    ctx = build_index(log)
    evaluate_box_indexed(ctx, box, parent_binding)
  end

  def evaluate_box_indexed(%IndexContext{} = ctx, %BindingBox{} = box, parent_binding \\ %{}) do
    # 1. Resolve variable domains efficiently with relation pushdown
    var_domains =
      Enum.map(box.vars, fn %VarDecl{name: name, kind: kind, types: types} ->
        # Check if this variable is constrained by a bound parent variable
        bound_from_o2o =
          Enum.find_value(box.predicates, fn
            {:o2o, src_var, ^name, qual} when is_map_key(parent_binding, src_var) ->
              src_id = Map.get(parent_binding, src_var)
              targets = Map.get(ctx.o2o_by_source, src_id, [])

              targets
              |> Enum.filter(fn {_t, q} -> is_nil(qual) or q == qual end)
              |> Enum.map(&elem(&1, 0))

            _ ->
              nil
          end)

        bound_from_e2o =
          Enum.find_value(box.predicates, fn
            {:e2o, ^name, obj_var, _qual} when is_map_key(parent_binding, obj_var) ->
              obj_id = Map.get(parent_binding, obj_var)
              Map.get(ctx.e2o_by_object, obj_id, [])

            _ ->
              nil
          end)

        candidates =
          cond do
            is_list(bound_from_o2o) ->
              bound_from_o2o

            is_list(bound_from_e2o) ->
              bound_from_e2o

            kind == :event ->
              if types == [] do
                Map.keys(ctx.event_map)
              else
                Enum.flat_map(types, &Map.get(ctx.events_by_type, &1, []))
              end

            kind == :object ->
              if types == [] do
                Map.values(ctx.objects_by_type) |> List.flatten()
              else
                Enum.flat_map(types, &Map.get(ctx.objects_by_type, &1, []))
              end
          end

        {name, candidates}
      end)

    # 2. Fast Cartesian Product & Predicate Filtering
    all_assignments = cartesian_product(var_domains, parent_binding)

    Enum.filter(all_assignments, fn assignment ->
      Enum.all?(box.predicates, fn pred -> check_predicate_indexed(ctx, pred, assignment) end)
    end)
  end

  defp eval_child_branch(ctx, %QueryTree{} = child_tree, parent_binding) do
    child_bindings = evaluate_box_indexed(ctx, child_tree.root_box, parent_binding)

    %{
      count: length(child_bindings),
      min: child_tree.min_children,
      max: child_tree.max_children,
      bindings: child_bindings
    }
  end

  defp check_predicate_indexed(ctx, {:e2o, ev_var, obj_var, qualifier}, assignment) do
    ev_id = Map.get(assignment, ev_var)
    obj_id = Map.get(assignment, obj_var)

    MapSet.member?(ctx.e2o_set, {ev_id, obj_id, nil}) or
      MapSet.member?(ctx.e2o_set, {ev_id, obj_id, qualifier})
  end

  defp check_predicate_indexed(ctx, {:o2o, src_var, tgt_var, qualifier}, assignment) do
    src_id = Map.get(assignment, src_var)
    tgt_id = Map.get(assignment, tgt_var)

    MapSet.member?(ctx.o2o_set, {src_id, tgt_id, qualifier}) or
      (is_nil(qualifier) and
         Enum.any?(ctx.o2o_set, fn {s, t, _q} -> s == src_id and t == tgt_id end))
  end

  defp check_predicate_indexed(ctx, {:tbe, ev_a_var, ev_b_var, op, threshold_ms}, assignment) do
    ev_a_id = Map.get(assignment, ev_a_var)
    ev_b_id = Map.get(assignment, ev_b_var)

    t_a = Map.get(ctx.time_map, ev_a_id)
    t_b = Map.get(ctx.time_map, ev_b_id)

    if t_a && t_b do
      diff = t_b - t_a

      case op do
        :< -> diff < threshold_ms
        :<= -> diff <= threshold_ms
        :== -> diff == threshold_ms
        :>= -> diff >= threshold_ms
        :> -> diff > threshold_ms
      end
    else
      false
    end
  end

  defp cartesian_product([], current), do: [current]

  defp cartesian_product([{var_name, values} | rest], current) do
    Enum.flat_map(values, fn val ->
      cartesian_product(rest, Map.put(current, var_name, val))
    end)
  end
end
