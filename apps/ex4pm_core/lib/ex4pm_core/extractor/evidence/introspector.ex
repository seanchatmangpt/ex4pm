defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Introspector do
  @moduledoc false

  def call(module, function, args) when is_atom(module) and is_atom(function) and is_list(args) do
    cond do
      not Code.ensure_loaded?(module) ->
        {:error, {:unsupported, :module_unavailable, module}}

      not function_exported?(module, function, length(args)) ->
        {:error, {:unsupported, :capability_unavailable, {module, function, length(args)}}}

      true ->
        try do
          {:ok, apply(module, function, args)}
        rescue
          error -> {:error, {:refused, :introspection_raised, error.__struct__}}
        catch
          kind, reason -> {:error, {:refused, :introspection_threw, {kind, reason}}}
        end
    end
  end
end
