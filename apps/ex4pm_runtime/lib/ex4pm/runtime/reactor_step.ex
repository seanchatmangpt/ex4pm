defmodule Ex4pm.Runtime.ReactorStep do
  @moduledoc "Canonical Reactor step for one admitted POWL task."

  use Reactor.Step

  alias Ex4pm.Refusal

  @impl true
  def run(%{task: task}, %{ex4pm: runtime_context}, _options) when is_map(runtime_context) do
    with {:ok, task_runner} <- fetch(runtime_context, :task_runner),
         true <- is_function(task_runner, 2),
         {:ok, run} <- task_runner.(task, runtime_context),
         {:ok, receipt} <- fetch_run(run, :receipt),
         {:ok, result} <- fetch_run(run, :result) do
      {:ok,
       %{
         task_id: task.id,
         result: result,
         pending: Map.get(run, :pending),
         receipt: receipt
       }}
    else
      false ->
        {:error,
         Refusal.new(:invalid_task_runner, "Reactor runtime requires a binary task runner")}

      {:error, %Refusal{} = refusal} ->
        {:error, refusal}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def run(arguments, context, _options) do
    {:error,
     Refusal.new(:invalid_reactor_step_context, "POWL Reactor step lacks admitted runtime context",
       details: %{arguments: inspect(arguments), context_keys: context_keys(context)}
     )}
  end

  defp fetch(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        {:error,
         Refusal.new(:missing_reactor_context, "Reactor runtime context is incomplete",
           details: %{key: key}
         )}
    end
  end

  defp fetch_run(run, key) when is_map(run) do
    case Map.fetch(run, key) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        {:error,
         Refusal.new(:invalid_task_runner_result, "task runner omitted required execution evidence",
           details: %{key: key}
         )}
    end
  end

  defp fetch_run(_run, key) do
    {:error,
     Refusal.new(:invalid_task_runner_result, "task runner returned a non-map success payload",
       details: %{key: key}
     )}
  end

  defp context_keys(context) when is_map(context), do: Map.keys(context)
  defp context_keys(_context), do: []
end

defmodule Ex4pm.Runtime.CollectorStep do
  @moduledoc false

  use Reactor.Step

  @impl true
  def run(_arguments, _context, _options), do: {:ok, :complete}
end
