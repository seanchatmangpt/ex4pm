defmodule Ex4pm.Runtime.Plan do
  @moduledoc "Reversible CONSTRUCT projection of an admitted POWL model into Reactor."
  @enforce_keys [:subject_hash, :reactor, :layers, :model]
  defstruct [:subject_hash, :reactor, :layers, :model, metadata: %{}]
end

defmodule Ex4pm.Runtime do
  @moduledoc "POWL-to-Reactor compiler and BRCE-governed execution facade."

  alias Ex4pm.Core.Hash
  alias Ex4pm.Evidence.BRCE
  alias Ex4pm.POWL
  alias Ex4pm.Refusal
  alias Ex4pm.Runtime.{CollectorStep, Intent, Plan, ReactorStep}
  alias Reactor.{Argument, Builder, Planner}

  @collector_name {:ex4pm, :collector}

  def compile(%POWL{} = model) do
    subject_hash = Hash.digest(model)

    layers =
      model
      |> POWL.layers()
      |> Enum.map(fn ids -> Enum.map(ids, &Map.fetch!(model.tasks, &1)) end)

    with {:ok, reactor} <- build_reactor(model, subject_hash),
         {:ok, reactor} <- Planner.plan(reactor) do
      {:ok,
       %Plan{
         subject_hash: subject_hash,
         reactor: reactor,
         layers: layers,
         model: model,
         metadata: %{
           task_count: map_size(model.tasks),
           layer_count: length(layers),
           mode: :construct,
           execution_kernel: Reactor,
           ash_extension: Ash.Reactor,
           scheduler: Reactor.Executor
         }
       }}
    else
      {:error, %Refusal{} = refusal} ->
        {:error, refusal}

      {:error, reason} ->
        {:error,
         Refusal.new(:reactor_compile_failed, "POWL could not be lowered into Reactor",
           subject: model,
           details: %{reason: inspect(reason)}
         )}
    end
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
    task_runner = Keyword.get(opts, :task_runner, default_task_runner(task_executor))

    context = %{
      ex4pm: %{
        authority: authority,
        store: store,
        subject_hash: plan.subject_hash,
        task_runner: task_runner
      }
    }

    run_options = [
      async?: true,
      fully_reversible?: true,
      max_concurrency: max_concurrency,
      max_iterations: Keyword.get(opts, :max_iterations, :infinity),
      timeout: Keyword.get(opts, :timeout, 30_000)
    ]

    case Reactor.run(plan.reactor, %{}, context, run_options) do
      {:ok, :complete, executed_reactor} ->
        build_execution(plan, executed_reactor)

      {:ok, result, _executed_reactor} ->
        {:error,
         Refusal.new(:unexpected_reactor_return, "canonical Reactor returned an unexpected value",
           subject: plan.model,
           details: %{result: inspect(result)}
         )}

      {:halted, halted_reactor} ->
        {:error,
         Refusal.new(:reactor_halted, "canonical Reactor halted before POWL completion",
           subject: plan.model,
           details: %{state: halted_reactor.state}
         )}

      {:error, reason} ->
        {:error, %{failure: public_failure(reason), completed_layers: []}}
    end
  end

  def execute(other, _authority, _opts) do
    {:error,
     Refusal.new(:invalid_execution_plan, "runtime execution requires a compiled plan",
       subject: other
     )}
  end

  def reactor_step_name(task_id), do: {:ex4pm_task, to_string(task_id)}

  defp default_task_runner(task_executor) do
    fn task, runtime_context ->
      operation = Intent.operation(task)

      BRCE.execute(
        runtime_context.subject_hash,
        operation,
        runtime_context.authority,
        fn -> task_executor.(task) end,
        store: runtime_context.store,
        metadata: %{runtime: :reactor, task_id: task.id, task_label: task.label}
      )
    end
  end

  defp build_reactor(model, subject_hash) do
    reactor = Builder.new({:ex4pm_powl, subject_hash})

    model.tasks
    |> Enum.sort_by(fn {id, _task} -> id end)
    |> Enum.reduce_while({:ok, reactor}, fn {id, task}, {:ok, current} ->
      arguments =
        [Argument.from_value(:task, task)] ++ dependency_arguments(model.edges, id)

      case Builder.add_step(current, reactor_step_name(id), ReactorStep, arguments,
             async?: true,
             max_retries: 0,
             ref: :step_name
           ) do
        {:ok, next} -> {:cont, {:ok, next}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> add_collector(model)
  end

  defp add_collector({:error, _reason} = error, _model), do: error

  defp add_collector({:ok, reactor}, model) do
    arguments =
      model
      |> terminal_task_ids()
      |> Enum.map(fn id -> Argument.from_result(:dependency, reactor_step_name(id)) end)

    with {:ok, reactor} <-
           Builder.add_step(reactor, @collector_name, CollectorStep, arguments,
             async?: false,
             max_retries: 0,
             ref: :step_name
           ),
         {:ok, reactor} <- Builder.return(reactor, @collector_name) do
      {:ok, reactor}
    end
  end

  defp dependency_arguments(edges, target_id) do
    edges
    |> Enum.filter(fn {_from, to} -> to == target_id end)
    |> Enum.sort()
    |> Enum.map(fn {from, _to} ->
      Argument.from_result(:dependency, reactor_step_name(from))
    end)
  end

  defp terminal_task_ids(%POWL{tasks: tasks, edges: edges}) do
    non_terminal = MapSet.new(edges, &elem(&1, 0))

    tasks
    |> Map.keys()
    |> Enum.reject(&MapSet.member?(non_terminal, &1))
    |> Enum.sort()
  end

  defp build_execution(plan, executed_reactor) do
    with {:ok, task_results} <- task_results(plan, executed_reactor.intermediate_results) do
      results_by_id = Map.new(task_results, &{&1.task_id, &1})

      layers =
        Enum.map(plan.layers, fn tasks ->
          Enum.map(tasks, fn task -> Map.fetch!(results_by_id, task.id) end)
        end)

      {:ok,
       %{
         plan_hash: Hash.digest(plan),
         subject_hash: plan.subject_hash,
         layers: layers,
         standing: :alive,
         runtime: :reactor,
         reactor_state: executed_reactor.state,
         receipt_hashes: for(layer <- layers, item <- layer, do: item.receipt.hash)
       }}
    end
  end

  defp task_results(plan, intermediate_results) do
    plan.model.tasks
    |> Map.keys()
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, fn id, {:ok, acc} ->
      case Map.fetch(intermediate_results, reactor_step_name(id)) do
        {:ok, result} ->
          {:cont, {:ok, [result | acc]}}

        :error ->
          {:halt,
           {:error,
            Refusal.new(:missing_reactor_task_result, "Reactor completed without a POWL task result",
              subject: plan.model,
              details: %{task_id: id}
            )}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp public_failure(%Refusal{} = refusal), do: refusal

  defp public_failure(%{error: error} = reactor_error) do
    case public_failure(error) do
      %Refusal{} = refusal -> refusal
      _ -> reactor_error
    end
  end

  defp public_failure(%{errors: errors} = reactor_error) when is_list(errors) do
    Enum.find_value(errors, reactor_error, fn error ->
      case public_failure(error) do
        %Refusal{} = refusal -> refusal
        _ -> nil
      end
    end)
  end

  defp public_failure(other), do: other
end
