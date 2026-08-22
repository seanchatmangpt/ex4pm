defmodule Ex4pm.Information.AshCatalog do
  @moduledoc """
  Read-only Ash projection for CLI and interop.

  Resource and action resolution is performed by comparing external strings to
  already-loaded public Ash metadata. No atom or module is manufactured from
  user input.
  """

  alias Ex4pm.Refusal

  def catalog do
    resources()
    |> Enum.map(&resource_descriptor/1)
  end

  def resources do
    Ex4pm.Domain
    |> Ash.Domain.Info.resources()
    |> Enum.uniq()
    |> Enum.sort_by(&resource_id/1)
  end

  def admit_read(resource_name, action_name, params)
      when is_binary(resource_name) and is_binary(action_name) and is_map(params) do
    with {:ok, resource} <- resolve_resource(resource_name),
         {:ok, action} <- resolve_public_action(resource, action_name),
         :ok <- require_read_action(action),
         :ok <- reject_unknown_action_inputs(resource, action, params) do
      {:ok, %{resource: resource, action: action.name}}
    end
  end

  def admit_read(resource_name, action_name, params) do
    {:error,
     Refusal.new(:invalid_ash_read_request, "Ash read requires resource, action, and params",
       details: %{resource: resource_name, action: action_name, params: params}
     )}
  end

  def read(%{resource: resource, action: action}, params, context) do
    query = Ash.Query.for_read(resource, action, params)

    read_opts =
      [domain: Ex4pm.Domain]
      |> maybe_put(:tenant, Map.get(context, "tenant"))

    Ash.read(query, read_opts)
  end

  def resolve_resource(name) when is_binary(name) do
    case Enum.find(resources(), fn resource ->
           name in [resource_id(resource), short_name(resource)]
         end) do
      nil ->
        {:error,
         Refusal.new(:unknown_ash_resource, "Ash resource is not part of the admitted domain",
           details: %{resource: name, admitted: Enum.map(resources(), &resource_id/1)}
         )}

      resource ->
        {:ok, resource}
    end
  end

  def resource_descriptor(resource) do
    %{
      id: resource_id(resource),
      short_name: short_name(resource),
      attributes:
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Enum.map(fn attribute ->
          %{
            name: attribute.name,
            type: inspect(attribute.type),
            allow_nil: attribute.allow_nil?,
            constraints: inspect(attribute.constraints)
          }
        end)
        |> Enum.sort_by(&to_string(&1.name)),
      actions:
        resource
        |> Ash.Resource.Info.public_actions()
        |> Enum.map(fn action ->
          %{
            name: action.name,
            type: action.type,
            description: action.description,
            inputs:
              resource
              |> Ash.Resource.Info.action_inputs(action.name)
              |> MapSet.to_list()
              |> Enum.map(&to_string/1)
              |> Enum.sort()
          }
        end)
        |> Enum.sort_by(&{to_string(&1.type), to_string(&1.name)})
    }
  end

  defp resolve_public_action(resource, name) do
    case resource
         |> Ash.Resource.Info.public_actions()
         |> Enum.find(&(to_string(&1.name) == name)) do
      nil ->
        {:error,
         Refusal.new(:unknown_public_ash_action, "Ash action is not public or does not exist",
           details: %{
             resource: resource_id(resource),
             action: name,
             admitted:
               resource
               |> Ash.Resource.Info.public_actions()
               |> Enum.map(&to_string(&1.name))
               |> Enum.sort()
           }
         )}

      action ->
        {:ok, action}
    end
  end

  defp require_read_action(%{type: :read}), do: :ok

  defp require_read_action(action) do
    {:error,
     Refusal.new(:ash_mutation_not_admitted, "generic Ash mutation is not admitted by this protocol",
       details: %{action: action.name, type: action.type, required: :read}
     )}
  end

  defp reject_unknown_action_inputs(resource, action, params) do
    allowed =
      resource
      |> Ash.Resource.Info.action_inputs(action.name)
      |> MapSet.to_list()
      |> Enum.map(&to_string/1)

    unknown =
      params
      |> Map.keys()
      |> Enum.map(&external_key/1)
      |> Enum.reject(&(&1 in allowed))
      |> Enum.sort()

    if unknown == [] do
      :ok
    else
      {:error,
       Refusal.new(:unknown_ash_action_input, "Ash action received unsupported input fields",
         details: %{unknown: unknown, allowed: Enum.sort(allowed)}
       )}
    end
  end

  defp resource_id(resource), do: inspect(resource)

  defp short_name(resource) do
    resource
    |> Ash.Resource.Info.short_name()
    |> to_string()
  end

  defp external_key(key) when is_binary(key), do: key
  defp external_key(key) when is_atom(key), do: Atom.to_string(key)
  defp external_key(key), do: inspect(key)

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
