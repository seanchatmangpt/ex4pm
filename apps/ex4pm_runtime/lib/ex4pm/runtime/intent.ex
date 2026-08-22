defmodule Ex4pm.Runtime.Intent do
  @moduledoc "Explicit executable intent projection shared by local and distributed runtimes."

  alias Ex4pm.Refusal

  def operation(%{intent: %{operation: operation}}), do: operation
  def operation(%{intent: %{"operation" => operation}}), do: operation
  def operation(task), do: {:powl_task, task.id}

  def execute(%{intent: %{fun: fun}}) when is_function(fun, 0), do: fun.()
  def execute(%{intent: %{"fun" => fun}}) when is_function(fun, 0), do: fun.()

  def execute(%{intent: %{mfa: {module, function, args}}})
      when is_atom(module) and is_atom(function) and is_list(args),
      do: apply(module, function, args)

  def execute(%{intent: {:mfa, module, function, args}})
      when is_atom(module) and is_atom(function) and is_list(args),
      do: apply(module, function, args)

  def execute(%{intent: %{value: value}}), do: value

  def execute(%{id: id, intent: intent}) do
    %{task_id: id, intent: intent, mode: :no_external_effect}
  end

  def execute(other) do
    {:error,
     Refusal.new(:invalid_runtime_intent, "runtime intent requires an admitted task",
       subject: other
     )}
  end
end
