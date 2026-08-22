defmodule Ex4pmCore.ProcessIR.Activity do
  @moduledoc "An atomic or compound activity node in ProcessIR."
  @enforce_keys [:id]
  defstruct [
    :id,
    :label,
    object_types: [],
    lifecycle_states: ["create", "start", "complete"],
    attributes: %{},
    guards: [],
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          label: String.t(),
          object_types: [String.t()],
          lifecycle_states: [String.t()],
          attributes: map(),
          guards: [String.t()],
          metadata: map()
        }
end

defmodule Ex4pmCore.ProcessIR.Choice do
  @moduledoc "A branching choice construct (XOR, OR, or generalized choice graph)."
  @enforce_keys [:id, :branches]
  defstruct [
    :id,
    :branches,
    type: :xor,
    conditions: %{},
    default_branch: nil,
    metadata: %{}
  ]

  @type choice_type :: :xor | :or | :deferrable | :choice_graph
  @type t :: %__MODULE__{
          id: String.t(),
          branches: [String.t()],
          type: choice_type(),
          conditions: %{optional(String.t()) => String.t()},
          default_branch: String.t() | nil,
          metadata: map()
        }
end

defmodule Ex4pmCore.ProcessIR.Loop do
  @moduledoc "An iterative loop construct (do-while / repeat-until / while-do)."
  @enforce_keys [:id, :body, :redo]
  defstruct [
    :id,
    :body,
    :redo,
    exit: nil,
    loop_condition: nil,
    max_iterations: nil,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          body: String.t(),
          redo: String.t(),
          exit: String.t() | nil,
          loop_condition: String.t() | nil,
          max_iterations: non_neg_integer() | nil,
          metadata: map()
        }
end

defmodule Ex4pmCore.ProcessIR.PartialOrder do
  @moduledoc "A strict partial order (DAG) of activities or sub-processes."
  @enforce_keys [:id, :nodes, :edges]
  defstruct [
    :id,
    :nodes,
    :edges,
    metadata: %{}
  ]

  @type edge :: {String.t(), String.t()}
  @type t :: %__MODULE__{
          id: String.t(),
          nodes: [String.t()],
          edges: [edge()],
          metadata: map()
        }
end

defmodule Ex4pmCore.ProcessIR.Guard do
  @moduledoc "A logical guard/condition predicate over event/object data."
  @enforce_keys [:id, :expression]
  defstruct [
    :id,
    :expression,
    description: "",
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          expression: map() | String.t() | term(),
          description: String.t(),
          metadata: map()
        }
end

defmodule Ex4pmCore.ProcessIR.Policy do
  @moduledoc "A governance, compliance, security, or temporal policy constraint."
  @enforce_keys [:id, :type]
  defstruct [
    :id,
    :type,
    target_activities: [],
    target_objects: [],
    rules: %{},
    description: "",
    metadata: %{}
  ]

  @type policy_type :: :sod | :bod | :sla | :mandatory | :forbidden | :cardinality | :custom
  @type t :: %__MODULE__{
          id: String.t(),
          type: policy_type(),
          target_activities: [String.t()],
          target_objects: [String.t()],
          rules: map(),
          description: String.t(),
          metadata: map()
        }
end

defmodule Ex4pmCore.ProcessIR.ObjectType do
  @moduledoc "An object type definition in an object-centric process."
  @enforce_keys [:id]
  defstruct [
    :id,
    name: nil,
    attributes: %{},
    lifecycle_states: [],
    cardinality: :many,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t() | nil,
          attributes: map(),
          lifecycle_states: [String.t()],
          cardinality: :one | :many | String.t(),
          metadata: map()
        }
end

defmodule Ex4pmCore.ProcessIR.Relationship do
  @moduledoc "A relationship definition between object types or event and objects."
  @enforce_keys [:id, :source, :target]
  defstruct [
    :id,
    :source,
    :target,
    type: :o2o,
    qualifier: "related",
    cardinality: "1..*",
    metadata: %{}
  ]

  @type rel_type :: :o2o | :o2m | :m2m | :e2o
  @type t :: %__MODULE__{
          id: String.t(),
          source: String.t(),
          target: String.t(),
          type: rel_type(),
          qualifier: String.t(),
          cardinality: String.t(),
          metadata: map()
        }
end

defmodule Ex4pmCore.ProcessIR do
  @moduledoc """
  Canonical Process Intermediate Representation (ProcessIR).
  Represents processes, activities, choices, loops, partial orders, guards, policies, objects, and relationships.
  """

  alias Ex4pm.Core.Hash
  alias Ex4pm.Refusal
  alias Ex4pm.Subject

  alias Ex4pmCore.ProcessIR.{
    Activity,
    Choice,
    Guard,
    Loop,
    ObjectType,
    PartialOrder,
    Policy,
    Relationship
  }

  @enforce_keys [:id]
  defstruct [
    :id,
    name: "",
    version: "1.0.0",
    activities: %{},
    choices: %{},
    loops: %{},
    partial_orders: %{},
    guards: %{},
    policies: %{},
    objects: %{},
    relationships: %{},
    root: nil,
    metadata: %{},
    subject: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          version: String.t(),
          activities: %{optional(String.t()) => Activity.t()},
          choices: %{optional(String.t()) => Choice.t()},
          loops: %{optional(String.t()) => Loop.t()},
          partial_orders: %{optional(String.t()) => PartialOrder.t()},
          guards: %{optional(String.t()) => Guard.t()},
          policies: %{optional(String.t()) => Policy.t()},
          objects: %{optional(String.t()) => ObjectType.t()},
          relationships: %{optional(String.t()) => Relationship.t()},
          root: String.t() | term() | nil,
          metadata: map(),
          subject: Subject.t() | nil
        }

  @doc "Constructs a new ProcessIR and validates referential integrity and acyclicity."
  def new(attrs \\ %{})

  def new(attrs) when is_map(attrs) do
    id = value(attrs, [:id, "id"]) || "process_#{System.unique_integer([:positive])}"
    name = value(attrs, [:name, "name"]) || to_string(id)
    version = value(attrs, [:version, "version"]) || "1.0.0"
    metadata = value(attrs, [:metadata, "metadata"]) || %{}
    root = value(attrs, [:root, "root"])

    with {:ok, activities} <-
           normalize_collection(value(attrs, [:activities, "activities"]), &normalize_activity/1),
         {:ok, choices} <-
           normalize_collection(value(attrs, [:choices, "choices"]), &normalize_choice/1),
         {:ok, loops} <- normalize_collection(value(attrs, [:loops, "loops"]), &normalize_loop/1),
         {:ok, pos} <-
           normalize_collection(
             value(attrs, [:partial_orders, "partial_orders"]),
             &normalize_partial_order/1
           ),
         {:ok, guards} <-
           normalize_collection(value(attrs, [:guards, "guards"]), &normalize_guard/1),
         {:ok, policies} <-
           normalize_collection(value(attrs, [:policies, "policies"]), &normalize_policy/1),
         {:ok, objects} <-
           normalize_collection(value(attrs, [:objects, "objects"]), &normalize_object_type/1),
         {:ok, relationships} <-
           normalize_collection(
             value(attrs, [:relationships, "relationships"]),
             &normalize_relationship/1
           ) do
      ir = %__MODULE__{
        id: to_string(id),
        name: to_string(name),
        version: to_string(version),
        activities: activities,
        choices: choices,
        loops: loops,
        partial_orders: pos,
        guards: guards,
        policies: policies,
        objects: objects,
        relationships: relationships,
        root: if(root, do: to_string(root), else: default_root(activities, pos, choices, loops)),
        metadata: metadata
      }

      with :ok <- validate(ir) do
        subject = Subject.new(:process_ir, to_canonical_map(ir))
        {:ok, %{ir | subject: subject}}
      end
    end
  end

  def new(other) do
    {:error,
     Refusal.new(:invalid_process_ir_attributes, "ProcessIR attributes must be a map",
       subject: other
     )}
  end

  @doc "Validates referential integrity, acyclic partial orders, and policy targets."
  def validate(%__MODULE__{} = ir) do
    with :ok <- validate_partial_orders(ir),
         :ok <- validate_choices(ir),
         :ok <- validate_loops(ir),
         :ok <- validate_policies(ir),
         :ok <- validate_relationships(ir) do
      :ok
    end
  end

  # Modifiers
  def add_activity(%__MODULE__{} = ir, activity) do
    with {:ok, act} <- normalize_activity(activity) do
      new_activities = Map.put(ir.activities, act.id, act)
      recalculate(%{ir | activities: new_activities})
    end
  end

  def add_choice(%__MODULE__{} = ir, choice) do
    with {:ok, ch} <- normalize_choice(choice) do
      new_choices = Map.put(ir.choices, ch.id, ch)
      recalculate(%{ir | choices: new_choices})
    end
  end

  def add_loop(%__MODULE__{} = ir, loop) do
    with {:ok, lp} <- normalize_loop(loop) do
      new_loops = Map.put(ir.loops, lp.id, lp)
      recalculate(%{ir | loops: new_loops})
    end
  end

  def add_partial_order(%__MODULE__{} = ir, po) do
    with {:ok, p} <- normalize_partial_order(po) do
      new_pos = Map.put(ir.partial_orders, p.id, p)
      recalculate(%{ir | partial_orders: new_pos})
    end
  end

  def add_guard(%__MODULE__{} = ir, guard) do
    with {:ok, gd} <- normalize_guard(guard) do
      new_guards = Map.put(ir.guards, gd.id, gd)
      recalculate(%{ir | guards: new_guards})
    end
  end

  def add_policy(%__MODULE__{} = ir, policy) do
    with {:ok, pol} <- normalize_policy(policy) do
      new_policies = Map.put(ir.policies, pol.id, pol)
      recalculate(%{ir | policies: new_policies})
    end
  end

  def add_object(%__MODULE__{} = ir, object_type) do
    with {:ok, obj} <- normalize_object_type(object_type) do
      new_objects = Map.put(ir.objects, obj.id, obj)
      recalculate(%{ir | objects: new_objects})
    end
  end

  def add_relationship(%__MODULE__{} = ir, relationship) do
    with {:ok, rel} <- normalize_relationship(relationship) do
      new_rels = Map.put(ir.relationships, rel.id, rel)
      recalculate(%{ir | relationships: new_rels})
    end
  end

  @doc "Deterministic digest of the ProcessIR."
  def digest(%__MODULE__{} = ir) do
    Hash.digest(to_canonical_map(ir))
  end

  @doc "Converts ProcessIR to a serializable map."
  def to_canonical_map(%__MODULE__{} = ir) do
    %{
      id: ir.id,
      name: ir.name,
      version: ir.version,
      activities: Map.new(ir.activities, fn {k, v} -> {k, Map.from_struct(v)} end),
      choices: Map.new(ir.choices, fn {k, v} -> {k, Map.from_struct(v)} end),
      loops: Map.new(ir.loops, fn {k, v} -> {k, Map.from_struct(v)} end),
      partial_orders: Map.new(ir.partial_orders, fn {k, v} -> {k, Map.from_struct(v)} end),
      guards: Map.new(ir.guards, fn {k, v} -> {k, Map.from_struct(v)} end),
      policies: Map.new(ir.policies, fn {k, v} -> {k, Map.from_struct(v)} end),
      objects: Map.new(ir.objects, fn {k, v} -> {k, Map.from_struct(v)} end),
      relationships: Map.new(ir.relationships, fn {k, v} -> {k, Map.from_struct(v)} end),
      root: ir.root,
      metadata: ir.metadata
    }
  end

  # Internal helpers & normalizers

  defp recalculate(%__MODULE__{} = ir) do
    with :ok <- validate(ir) do
      subject = Subject.new(:process_ir, to_canonical_map(ir))
      {:ok, %{ir | subject: subject}}
    end
  end

  defp default_root(_acts, pos, choices, loops) do
    cond do
      map_size(pos) == 1 -> hd(Map.keys(pos))
      map_size(choices) == 1 -> hd(Map.keys(choices))
      map_size(loops) == 1 -> hd(Map.keys(loops))
      true -> nil
    end
  end

  defp normalize_collection(nil, _fun), do: {:ok, %{}}
  defp normalize_collection([], _fun), do: {:ok, %{}}

  defp normalize_collection(items, fun) when is_list(items) do
    items
    |> Enum.reduce_while({:ok, %{}}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, struct} -> {:cont, {:ok, Map.put(acc, struct.id, struct)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp normalize_collection(map, fun) when is_map(map) do
    map
    |> Enum.reduce_while({:ok, %{}}, fn {key, item}, {:ok, acc} ->
      item =
        if is_map(item) and not Map.has_key?(item, :id) and not Map.has_key?(item, "id"),
          do: Map.put(item, :id, key),
          else: item

      case fun.(item) do
        {:ok, struct} -> {:cont, {:ok, Map.put(acc, struct.id, struct)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp normalize_collection(other, _fun) do
    {:error, Refusal.new(:invalid_collection, "Collection must be a list or map", subject: other)}
  end

  defp normalize_activity(%Activity{} = a),
    do: {:ok, %{a | id: to_string(a.id), label: to_string(a.label || a.id)}}

  defp normalize_activity(map) when is_map(map) do
    id = value(map, [:id, "id"])

    if is_nil(id) do
      {:error, Refusal.new(:missing_activity_id, "Activity is missing id", subject: map)}
    else
      id = to_string(id)
      label = to_string(value(map, [:label, "label"]) || id)
      obj_types = value(map, [:object_types, "object_types", :objects, "objects"]) || []

      lc_states =
        value(map, [:lifecycle_states, "lifecycle_states"]) || ["create", "start", "complete"]

      attrs = value(map, [:attributes, "attributes"]) || %{}
      guards = value(map, [:guards, "guards"]) || []
      meta = value(map, [:metadata, "metadata"]) || %{}

      {:ok,
       %Activity{
         id: id,
         label: label,
         object_types: Enum.map(List.wrap(obj_types), &to_string/1),
         lifecycle_states: Enum.map(List.wrap(lc_states), &to_string/1),
         attributes: attrs,
         guards: Enum.map(List.wrap(guards), &to_string/1),
         metadata: meta
       }}
    end
  end

  defp normalize_activity(other),
    do:
      {:error, Refusal.new(:invalid_activity, "Activity must be a map or struct", subject: other)}

  defp normalize_choice(%Choice{} = c),
    do: {:ok, %{c | id: to_string(c.id), branches: Enum.map(c.branches, &to_string/1)}}

  defp normalize_choice(map) when is_map(map) do
    id = value(map, [:id, "id"])
    branches = value(map, [:branches, "branches"])

    if is_nil(id) or is_nil(branches) or not is_list(branches) do
      {:error,
       Refusal.new(:invalid_choice, "Choice must contain id and branches list", subject: map)}
    else
      type = value(map, [:type, "type"]) || :xor
      conds = value(map, [:conditions, "conditions"]) || %{}
      default_b = value(map, [:default_branch, "default_branch"])
      meta = value(map, [:metadata, "metadata"]) || %{}

      {:ok,
       %Choice{
         id: to_string(id),
         branches: Enum.map(branches, &to_string/1),
         type: if(is_binary(type), do: String.to_existing_atom(type), else: type),
         conditions: Map.new(conds, fn {k, v} -> {to_string(k), to_string(v)} end),
         default_branch: if(default_b, do: to_string(default_b), else: nil),
         metadata: meta
       }}
    end
  end

  defp normalize_choice(other),
    do: {:error, Refusal.new(:invalid_choice, "Choice must be a map or struct", subject: other)}

  defp normalize_loop(%Loop{} = l),
    do: {:ok, %{l | id: to_string(l.id), body: to_string(l.body), redo: to_string(l.redo)}}

  defp normalize_loop(map) when is_map(map) do
    id = value(map, [:id, "id"])
    body = value(map, [:body, "body"])
    redo = value(map, [:redo, "redo"])

    if is_nil(id) or is_nil(body) or is_nil(redo) do
      {:error, Refusal.new(:invalid_loop, "Loop must specify id, body, and redo", subject: map)}
    else
      exit_b = value(map, [:exit, "exit"])
      cond_g = value(map, [:loop_condition, "loop_condition"])
      max_it = value(map, [:max_iterations, "max_iterations"])
      meta = value(map, [:metadata, "metadata"]) || %{}

      {:ok,
       %Loop{
         id: to_string(id),
         body: to_string(body),
         redo: to_string(redo),
         exit: if(exit_b, do: to_string(exit_b), else: nil),
         loop_condition: if(cond_g, do: to_string(cond_g), else: nil),
         max_iterations: max_it,
         metadata: meta
       }}
    end
  end

  defp normalize_loop(other),
    do: {:error, Refusal.new(:invalid_loop, "Loop must be a map or struct", subject: other)}

  defp normalize_partial_order(%PartialOrder{} = p) do
    edges = Enum.map(p.edges, fn {f, t} -> {to_string(f), to_string(t)} end)
    {:ok, %{p | id: to_string(p.id), nodes: Enum.map(p.nodes, &to_string/1), edges: edges}}
  end

  defp normalize_partial_order(map) when is_map(map) do
    id = value(map, [:id, "id"])
    nodes = value(map, [:nodes, "nodes"]) || []
    edges = value(map, [:edges, "edges"]) || []

    if is_nil(id) do
      {:error, Refusal.new(:missing_po_id, "PartialOrder is missing id", subject: map)}
    else
      norm_nodes = Enum.map(nodes, &to_string/1)

      norm_edges =
        Enum.map(edges, fn
          {f, t} -> {to_string(f), to_string(t)}
          [f, t] -> {to_string(f), to_string(t)}
          %{"from" => f, "to" => t} -> {to_string(f), to_string(t)}
        end)

      meta = value(map, [:metadata, "metadata"]) || %{}

      {:ok,
       %PartialOrder{
         id: to_string(id),
         nodes: norm_nodes,
         edges: norm_edges,
         metadata: meta
       }}
    end
  end

  defp normalize_partial_order(other),
    do:
      {:error,
       Refusal.new(:invalid_partial_order, "PartialOrder must be a map or struct", subject: other)}

  defp normalize_guard(%Guard{} = g), do: {:ok, %{g | id: to_string(g.id)}}

  defp normalize_guard(map) when is_map(map) do
    id = value(map, [:id, "id"])
    expr = value(map, [:expression, "expression", :expr, "expr"])

    if is_nil(id) or is_nil(expr) do
      {:error, Refusal.new(:invalid_guard, "Guard must contain id and expression", subject: map)}
    else
      desc = value(map, [:description, "description"]) || ""
      meta = value(map, [:metadata, "metadata"]) || %{}

      {:ok,
       %Guard{id: to_string(id), expression: expr, description: to_string(desc), metadata: meta}}
    end
  end

  defp normalize_guard(other),
    do: {:error, Refusal.new(:invalid_guard, "Guard must be a map or struct", subject: other)}

  defp normalize_policy(%Policy{} = p), do: {:ok, %{p | id: to_string(p.id)}}

  defp normalize_policy(map) when is_map(map) do
    id = value(map, [:id, "id"])
    type = value(map, [:type, "type"])

    if is_nil(id) or is_nil(type) do
      {:error, Refusal.new(:invalid_policy, "Policy must contain id and type", subject: map)}
    else
      type_atom = if is_binary(type), do: String.to_existing_atom(type), else: type

      acts =
        value(map, [:target_activities, "target_activities", :activities, "activities"]) || []

      objs = value(map, [:target_objects, "target_objects", :objects, "objects"]) || []
      rules = value(map, [:rules, "rules"]) || %{}
      desc = value(map, [:description, "description"]) || ""
      meta = value(map, [:metadata, "metadata"]) || %{}

      {:ok,
       %Policy{
         id: to_string(id),
         type: type_atom,
         target_activities: Enum.map(List.wrap(acts), &to_string/1),
         target_objects: Enum.map(List.wrap(objs), &to_string/1),
         rules: rules,
         description: to_string(desc),
         metadata: meta
       }}
    end
  end

  defp normalize_policy(other),
    do: {:error, Refusal.new(:invalid_policy, "Policy must be a map or struct", subject: other)}

  defp normalize_object_type(%ObjectType{} = o), do: {:ok, %{o | id: to_string(o.id)}}

  defp normalize_object_type(map) when is_map(map) do
    id = value(map, [:id, "id"])

    if is_nil(id) do
      {:error, Refusal.new(:missing_object_type_id, "ObjectType is missing id", subject: map)}
    else
      id = to_string(id)
      name = to_string(value(map, [:name, "name"]) || id)
      attrs = value(map, [:attributes, "attributes"]) || %{}
      lc = value(map, [:lifecycle_states, "lifecycle_states"]) || []
      card = value(map, [:cardinality, "cardinality"]) || :many
      meta = value(map, [:metadata, "metadata"]) || %{}

      {:ok,
       %ObjectType{
         id: id,
         name: name,
         attributes: attrs,
         lifecycle_states: Enum.map(List.wrap(lc), &to_string/1),
         cardinality: card,
         metadata: meta
       }}
    end
  end

  defp normalize_object_type(other),
    do:
      {:error,
       Refusal.new(:invalid_object_type, "ObjectType must be a map or struct", subject: other)}

  defp normalize_relationship(%Relationship{} = r),
    do:
      {:ok, %{r | id: to_string(r.id), source: to_string(r.source), target: to_string(r.target)}}

  defp normalize_relationship(map) when is_map(map) do
    id = value(map, [:id, "id"])
    src = value(map, [:source, "source"])
    tgt = value(map, [:target, "target"])

    if is_nil(id) or is_nil(src) or is_nil(tgt) do
      {:error,
       Refusal.new(:invalid_relationship, "Relationship must contain id, source, and target",
         subject: map
       )}
    else
      type = value(map, [:type, "type"]) || :o2o
      qual = value(map, [:qualifier, "qualifier"]) || "related"
      card = value(map, [:cardinality, "cardinality"]) || "1..*"
      meta = value(map, [:metadata, "metadata"]) || %{}

      {:ok,
       %Relationship{
         id: to_string(id),
         source: to_string(src),
         target: to_string(tgt),
         type: if(is_binary(type), do: String.to_existing_atom(type), else: type),
         qualifier: to_string(qual),
         cardinality: to_string(card),
         metadata: meta
       }}
    end
  end

  defp normalize_relationship(other),
    do:
      {:error,
       Refusal.new(:invalid_relationship, "Relationship must be a map or struct", subject: other)}

  defp validate_partial_orders(%__MODULE__{partial_orders: pos, activities: acts}) do
    Enum.reduce_while(pos, :ok, fn {po_id, po}, :ok ->
      all_ids = Map.keys(acts) |> MapSet.new() |> MapSet.union(MapSet.new(po.nodes))

      invalid_edges =
        Enum.reject(po.edges, fn {from, to} ->
          MapSet.member?(all_ids, from) and MapSet.member?(all_ids, to)
        end)

      if invalid_edges != [] do
        {:halt,
         {:error,
          Refusal.new(:invalid_partial_order_edge, "Partial order edge references unknown node",
            details: %{partial_order: po_id, invalid_edges: invalid_edges}
          )}}
      else
        case check_dag(po.nodes, po.edges) do
          :ok -> {:cont, :ok}
          {:error, _} = err -> {:halt, err}
        end
      end
    end)
  end

  defp check_dag(nodes, edges) do
    node_set =
      MapSet.new(nodes) |> MapSet.union(MapSet.new(Enum.flat_map(edges, fn {f, t} -> [f, t] end)))

    indegree =
      Enum.reduce(edges, Map.new(node_set, fn id -> {id, 0} end), fn {_from, to}, acc ->
        Map.update(acc, to, 1, &(&1 + 1))
      end)

    successors = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    case consume_dag(indegree, successors, 0) do
      count when count == map_size(indegree) -> :ok
      _ -> {:error, Refusal.new(:cyclic_partial_order, "Partial order contains a directed cycle")}
    end
  end

  defp consume_dag(indegree, successors, count) do
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

      consume_dag(next, successors, count + length(zeros))
    end
  end

  defp validate_choices(%__MODULE__{choices: choices, activities: acts, partial_orders: pos}) do
    all_valid_ids = MapSet.new(Map.keys(acts) ++ Map.keys(pos) ++ Map.keys(choices))

    Enum.reduce_while(choices, :ok, fn {ch_id, choice}, :ok ->
      invalid_branches = Enum.reject(choice.branches, &MapSet.member?(all_valid_ids, &1))

      if invalid_branches != [] do
        {:halt,
         {:error,
          Refusal.new(:invalid_choice_branch, "Choice branch references unknown node",
            details: %{choice: ch_id, invalid_branches: invalid_branches}
          )}}
      else
        {:cont, :ok}
      end
    end)
  end

  defp validate_loops(%__MODULE__{
         loops: loops,
         activities: acts,
         partial_orders: pos,
         choices: choices
       }) do
    all_valid_ids =
      MapSet.new(Map.keys(acts) ++ Map.keys(pos) ++ Map.keys(choices) ++ Map.keys(loops))

    Enum.reduce_while(loops, :ok, fn {lp_id, loop}, :ok ->
      cond do
        not MapSet.member?(all_valid_ids, loop.body) ->
          {:halt,
           {:error,
            Refusal.new(:invalid_loop_body, "Loop body references unknown node",
              details: %{loop: lp_id, body: loop.body}
            )}}

        not MapSet.member?(all_valid_ids, loop.redo) ->
          {:halt,
           {:error,
            Refusal.new(:invalid_loop_redo, "Loop redo references unknown node",
              details: %{loop: lp_id, redo: loop.redo}
            )}}

        loop.exit != nil and not MapSet.member?(all_valid_ids, loop.exit) ->
          {:halt,
           {:error,
            Refusal.new(:invalid_loop_exit, "Loop exit references unknown node",
              details: %{loop: lp_id, exit: loop.exit}
            )}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_policies(%__MODULE__{policies: policies, activities: acts}) do
    act_ids = MapSet.new(Map.keys(acts))

    Enum.reduce_while(policies, :ok, fn {pol_id, pol}, :ok ->
      invalid_acts = Enum.reject(pol.target_activities, &MapSet.member?(act_ids, &1))

      if invalid_acts != [] do
        {:halt,
         {:error,
          Refusal.new(:invalid_policy_target, "Policy references unknown activity",
            details: %{policy: pol_id, unknown_activities: invalid_acts}
          )}}
      else
        {:cont, :ok}
      end
    end)
  end

  defp validate_relationships(%__MODULE__{relationships: rels, objects: objs}) do
    obj_ids = MapSet.new(Map.keys(objs))

    Enum.reduce_while(rels, :ok, fn {rel_id, rel}, :ok ->
      if rel.type in [:o2o, :o2m, :m2m] and
           (not MapSet.member?(obj_ids, rel.source) or not MapSet.member?(obj_ids, rel.target)) do
        {:halt,
         {:error,
          Refusal.new(:invalid_relationship_object, "Relationship references unknown object type",
            details: %{relationship: rel_id, source: rel.source, target: rel.target}
          )}}
      else
        {:cont, :ok}
      end
    end)
  end

  defp value(map, keys), do: Enum.find_value(keys, &Map.get(map, &1))
end

defmodule Ex4pm.Core.ProcessIR do
  @moduledoc "Alias module for Ex4pmCore.ProcessIR."
  defdelegate new(attrs \\ %{}), to: Ex4pmCore.ProcessIR
  defdelegate validate(ir), to: Ex4pmCore.ProcessIR
  defdelegate add_activity(ir, activity), to: Ex4pmCore.ProcessIR
  defdelegate add_choice(ir, choice), to: Ex4pmCore.ProcessIR
  defdelegate add_loop(ir, loop), to: Ex4pmCore.ProcessIR
  defdelegate add_partial_order(ir, po), to: Ex4pmCore.ProcessIR
  defdelegate add_guard(ir, guard), to: Ex4pmCore.ProcessIR
  defdelegate add_policy(ir, policy), to: Ex4pmCore.ProcessIR
  defdelegate add_object(ir, object_type), to: Ex4pmCore.ProcessIR
  defdelegate add_relationship(ir, relationship), to: Ex4pmCore.ProcessIR
  defdelegate digest(ir), to: Ex4pmCore.ProcessIR
  defdelegate to_canonical_map(ir), to: Ex4pmCore.ProcessIR
end
