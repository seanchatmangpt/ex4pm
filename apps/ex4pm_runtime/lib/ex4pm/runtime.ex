defmodule Ex4pm.Runtime.Plan do
  @moduledoc "Reversible CONSTRUCT projection of a POWL model."
  @enforce_keys [:subject_hash, :layers, :model]
  defstruct [:subject_hash, :layers, :model, metadata: %{}]
end

defmodule Ex4pm.Runtime do
  @moduledoc "POWL compiler and BRCE-governed OTP execution runtime."

  alias Ex4pm.Core.Hash
  alias Ex4pm.Evidence.BRCE
  alias Ex4pm.POWL
  alias Ex4pm.Refusal
  alias Ex4pm.Runtime.{Intent, Plan}

  def compile(%POWL{} = model) do
    layers =
      model
      |> POWL.layers()
      |> Enum.map(fn ids -> Enum.map(ids, &Map.fetch!(model.tasks, &1)) end)

    {:ok,
     %Plan{
       subject_hash: Hash.digest(model),
       layers: layers,
       model: model,
       metadata: %{
         task_count: map_size(model.tasks),
         layer_count: length(layers),
         mode: :construct
       }
     }}
  end

  def compile(other) do
    {:error,
     Refusal.new(:invalid_runtime_model, "runtime compilation requires an admitted POWL model",
       subject: other
     )}
  end

  def execute(plan, authority, opts \\ [])

  def execute(%Plan{} = plan, authority, opts) do
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    task_executor = Keyword.get(opts, :task_executor, &Intent.execute/1)
    store = Keyword.get(opts, :store, Ex4pm.Evidence.Store)

    Enum.reduce_while(plan.layers, {:ok, []}, fn layer, {:ok, completed_layers} ->
      results =
        Task.Supervisor.async_stream_nolink(
          Ex4pm.Runtime.TaskSupervisor,
          layer,
          fn task -> execute_task(plan, task, authority, task_executor, store) end,
          ordered: true,
          max_concurrency: max_concurrency,
          timeout: Keyword.get(opts, :timeout, 30_000)
        )
        |> Enum.to_list()

      case normalize_layer_results(results) do
        {:ok, layer_results} ->
          {:cont, {:ok, [layer_results | completed_layers]}}

        {:error, failure} ->
          {:halt, {:error, %{failure: failure, completed_layers: Enum.reverse(completed_layers)}}}
      end
    end)
    |> case do
      {:ok, layers} ->
        trace = Enum.reverse(layers)

        {:ok,
         %{
           plan_hash: Hash.digest(plan),
           subject_hash: plan.subject_hash,
           layers: trace,
           standing: :alive,
           receipt_hashes: for(layer <- trace, item <- layer, do: item.receipt.hash)
         }}

      error ->
        error
    end
  end

  def execute(other, _authority, _opts) do
    {:error,
     Refusal.new(:invalid_execution_plan, "runtime execution requires a compiled plan",
       subject: other
     )}
  end

  defp execute_task(plan, task, authority, task_executor, store) do
    operation = Intent.operation(task)

    BRCE.execute(plan.subject_hash, operation, authority, fn -> task_executor.(task) end,
      store: store,
      metadata: %{task_id: task.id, task_label: task.label}
    )
  end

  defp normalize_layer_results(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, {:ok, %{result: result, receipt: receipt}}}, {:ok, acc} ->
        {:cont, {:ok, [%{result: result, receipt: receipt} | acc]}}

      {:ok, {:error, failure}}, _acc ->
        {:halt, {:error, failure}}

      {:exit, reason}, _acc ->
        {:halt,
         {:error,
          Refusal.new(:task_process_exit, "supervised POWL task exited",
            details: %{reason: inspect(reason)}
          )}}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end
end
