defmodule Ex4pmCore.ProcessIR.Extractor.Ash do
  @moduledoc """
  Extracts Ash Resource and Domain definitions into canonical ProcessIR.

  Introspects actions, attributes, calculations, aggregates, and field-level policies,
  mapping actions to ProcessIR.Activity nodes and relationships to ProcessIR.Relationship.
  """

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.{Activity, ObjectType, Policy, Relationship}

  @doc "Extracts a single Ash resource or a list of resources into a ProcessIR struct."
  def extract(resource_or_resources, opts \\ [])

  def extract(resources, opts) when is_list(resources) do
    process_id = Keyword.get(opts, :id, "ash_process_#{System.unique_integer([:positive])}")
    process_name = Keyword.get(opts, :name, "Ash Domain Process")

    activities =
      Enum.flat_map(resources, fn res ->
        extract_resource_activities(res)
      end)
      |> Enum.map(&{&1.id, &1})
      |> Map.new()

    objects =
      Enum.map(resources, fn res ->
        obj = extract_resource_object(res)
        {obj.id, obj}
      end)
      |> Map.new()

    relationships =
      Enum.flat_map(resources, fn res ->
        extract_resource_relationships(res)
      end)
      |> Enum.map(&{&1.id, &1})
      |> Map.new()

    policies =
      Enum.flat_map(resources, fn res ->
        extract_resource_policies(res)
      end)
      |> Enum.map(&{&1.id, &1})
      |> Map.new()

    %ProcessIR{
      id: to_string(process_id),
      name: to_string(process_name),
      version: "1.0.0",
      activities: activities,
      objects: objects,
      relationships: relationships,
      policies: policies,
      metadata: %{source: :ash_introspection, resource_count: length(resources)}
    }
  end

  def extract(resource, opts) when is_atom(resource) do
    extract([resource], opts)
  end

  defp extract_resource_activities(resource) do
    Code.ensure_loaded(resource)
    res_name = resource_name(resource)

    actions =
      cond do
        Code.ensure_loaded?(Ash.Resource.Info) and
            function_exported?(Ash.Resource.Info, :actions, 1) ->
          try do
            apply(Ash.Resource.Info, :actions, [resource])
          rescue
            _ -> []
          end

        function_exported?(Module.concat(resource, Info), :actions, 1) ->
          try do
            apply(Module.concat(resource, Info), :actions, [resource])
          rescue
            _ -> []
          end

        true ->
          []
      end

    Enum.map(actions, fn action ->
      act_name = Map.get(action, :name)
      act_type = Map.get(action, :type, :custom)
      act_id = "#{res_name}.#{act_name}"

      %Activity{
        id: act_id,
        label: "#{act_type} #{act_name} on #{res_name}",
        object_types: [res_name],
        lifecycle_states: ["create", "start", "complete"],
        attributes: %{
          action_type: act_type,
          primary?: Map.get(action, :primary?, false),
          accept: Map.get(action, :accept, [])
        },
        metadata: %{resource: inspect(resource), action_name: act_name}
      }
    end)
  end

  defp extract_resource_object(resource) do
    Code.ensure_loaded(resource)
    res_name = resource_name(resource)

    attributes =
      cond do
        Code.ensure_loaded?(Ash.Resource.Info) and
            function_exported?(Ash.Resource.Info, :attributes, 1) ->
          try do
            apply(Ash.Resource.Info, :attributes, [resource])
            |> Enum.map(fn attr ->
              {to_string(attr.name), %{type: inspect(attr.type), allow_nil?: attr.allow_nil?}}
            end)
            |> Map.new()
          rescue
            _ -> %{}
          end

        function_exported?(Module.concat(resource, Info), :attributes, 1) ->
          try do
            apply(Module.concat(resource, Info), :attributes, [resource])
            |> Enum.map(fn attr ->
              {to_string(attr.name), %{type: inspect(attr.type), allow_nil?: attr.allow_nil?}}
            end)
            |> Map.new()
          rescue
            _ -> %{}
          end

        true ->
          %{}
      end

    %ObjectType{
      id: res_name,
      name: res_name,
      attributes: attributes,
      metadata: %{module: inspect(resource)}
    }
  end

  defp extract_resource_relationships(resource) do
    Code.ensure_loaded(resource)
    res_name = resource_name(resource)

    relationships =
      cond do
        Code.ensure_loaded?(Ash.Resource.Info) and
            function_exported?(Ash.Resource.Info, :relationships, 1) ->
          try do
            apply(Ash.Resource.Info, :relationships, [resource])
          rescue
            _ -> []
          end

        function_exported?(Module.concat(resource, Info), :relationships, 1) ->
          try do
            apply(Module.concat(resource, Info), :relationships, [resource])
          rescue
            _ -> []
          end

        true ->
          []
      end

    Enum.map(relationships, fn rel ->
      dest_name = resource_name(rel.destination)
      rel_id = "#{res_name}_#{rel.name}_#{dest_name}"

      rel_type =
        case Map.get(rel, :cardinality) do
          :one -> :o2o
          :many -> :o2m
          _ -> :o2o
        end

      %Relationship{
        id: rel_id,
        source: res_name,
        target: dest_name,
        type: rel_type,
        qualifier: to_string(rel.name),
        cardinality: if(Map.get(rel, :cardinality) == :one, do: "1..1", else: "1..*"),
        metadata: %{
          source_attribute: Map.get(rel, :source_attribute),
          destination_attribute: Map.get(rel, :destination_attribute)
        }
      }
    end)
  end

  defp extract_resource_policies(resource) do
    Code.ensure_loaded(resource)
    res_name = resource_name(resource)

    try do
      if Code.ensure_loaded?(Ash.Policy.Info) and
           function_exported?(Ash.Policy.Info, :policies, 1) do
        apply(Ash.Policy.Info, :policies, [resource])
        |> Enum.with_index(1)
        |> Enum.map(fn {policy, idx} ->
          %Policy{
            id: "#{res_name}_policy_#{idx}",
            type: :custom,
            target_objects: [res_name],
            description: "Ash policy for #{res_name}",
            metadata: %{policy: inspect(policy)}
          }
        end)
      else
        []
      end
    rescue
      _ -> []
    end
  end

  defp resource_name(resource) do
    resource
    |> Module.split()
    |> List.last()
  end
end
