defmodule Ex4pmEngine.Cognition.Ocpq do
  @moduledoc """
  Object-Centric Process Querying & Constraints (OCPQ).
  Faithful BEAM realization of Küsters & van der Aalst (arXiv:2506.11541v1, 2025).

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

  @doc "Evaluates an OCPQ QueryTree against an EventLog, checking whether all constraints hold."
  def evaluate_query(%EventLog{} = log, %QueryTree{} = tree) do
    # 1. Extract bindings matching the root box
    root_bindings = evaluate_box(log, tree.root_box)

    # 2. Check child branch conditions for each root binding
    violations =
      Enum.flat_map(root_bindings, fn root_binding ->
        child_results =
          Enum.map(tree.children, fn child_tree ->
            eval_child_branch(log, child_tree, root_binding)
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

  @doc "Evaluates a single BindingBox against an EventLog, returning valid variable assignments."
  def evaluate_box(%EventLog{} = log, %BindingBox{} = box, parent_binding \\ %{}) do
    # Generate domain candidates for each variable in box
    var_domains =
      Enum.map(box.vars, fn %VarDecl{name: name, kind: kind, types: types} ->
        candidates =
          case kind do
            :event ->
              log.events
              |> Enum.filter(fn ev -> types == [] or ev.activity in types end)
              |> Enum.map(& &1.id)

            :object ->
              log.objects
              |> Enum.filter(fn {_id, obj} -> types == [] or obj.type in types end)
              |> Enum.map(&elem(&1, 0))
          end

        {name, candidates}
      end)

    # Cross product of variable domains
    all_assignments = cartesian_product(var_domains, parent_binding)

    # Filter assignments satisfying all basic predicates in box
    Enum.filter(all_assignments, fn assignment ->
      Enum.all?(box.predicates, fn pred -> check_predicate(log, pred, assignment) end)
    end)
  end

  defp eval_child_branch(log, %QueryTree{} = child_tree, parent_binding) do
    child_bindings = evaluate_box(log, child_tree.root_box, parent_binding)

    %{
      count: length(child_bindings),
      min: child_tree.min_children,
      max: child_tree.max_children,
      bindings: child_bindings
    }
  end

  defp check_predicate(log, {:e2o, ev_var, obj_var, qualifier}, assignment) do
    ev_id = Map.get(assignment, ev_var)
    obj_id = Map.get(assignment, obj_var)

    event = Enum.find(log.events, &(&1.id == ev_id))

    if event do
      in_objects? = obj_id in event.object_ids

      in_relationships? =
        Enum.any?(event.relationships, fn rel ->
          rel_obj =
            Map.get(rel, "objectId") || Map.get(rel, "object_id") || Map.get(rel, :object_id)

          rel_qual = Map.get(rel, "qualifier") || Map.get(rel, :qualifier)
          rel_obj == obj_id and (is_nil(qualifier) or rel_qual == qualifier)
        end)

      in_objects? or in_relationships?
    else
      false
    end
  end

  defp check_predicate(log, {:o2o, src_var, tgt_var, qualifier}, assignment) do
    src_id = Map.get(assignment, src_var)
    tgt_id = Map.get(assignment, tgt_var)

    Enum.any?(log.object_relationships, fn rel ->
      rel.source_id == src_id and rel.target_id == tgt_id and
        (is_nil(qualifier) or rel.qualifier == qualifier)
    end)
  end

  defp check_predicate(log, {:tbe, ev_a_var, ev_b_var, op, threshold_ms}, assignment) do
    ev_a_id = Map.get(assignment, ev_a_var)
    ev_b_id = Map.get(assignment, ev_b_var)

    ev_a = Enum.find(log.events, &(&1.id == ev_a_id))
    ev_b = Enum.find(log.events, &(&1.id == ev_b_id))

    if ev_a && ev_b do
      with {:ok, dt_a, _} <- DateTime.from_iso8601(to_string(ev_a.timestamp)),
           {:ok, dt_b, _} <- DateTime.from_iso8601(to_string(ev_b.timestamp)) do
        diff = DateTime.diff(dt_b, dt_a, :millisecond)

        case op do
          :< -> diff < threshold_ms
          :<= -> diff <= threshold_ms
          :== -> diff == threshold_ms
          :>= -> diff >= threshold_ms
          :> -> diff > threshold_ms
        end
      else
        _ -> false
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
