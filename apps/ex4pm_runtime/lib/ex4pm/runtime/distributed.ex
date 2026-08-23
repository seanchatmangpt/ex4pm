defmodule Ex4pm.Runtime.Distributed do
  @moduledoc "Evidence-bounded distributed POWL execution over Erlang distribution."

  alias Ex4pm.Evidence.{Replay, Store}
  alias Ex4pm.Refusal
  alias Ex4pm.Runtime.{Intent, Plan}

  def execute(plan, authority, opts \\ [])

  def execute(%Plan{} = plan, authority, opts) do
    nodes = opts |> Keyword.get(:nodes, []) |> Enum.uniq()
    timeout = Keyword.get(opts, :timeout, 30_000)
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    origin_store = Keyword.get(opts, :store, Store)
    remote_store = Keyword.get(opts, :remote_store, Store)

    with :ok <- admit_distribution(nodes),
         :ok <- admit_nodes(nodes) do
      execute_layers(
        plan,
        authority,
        nodes,
        timeout,
        max_concurrency,
        origin_store,
        remote_store
      )
    end
  end

  def execute(other, _authority, _opts) do
    {:error,
     Refusal.new(
       :invalid_distributed_execution_plan,
       "distributed execution requires a compiled runtime plan",
       subject: other
     )}
  end

  def execute_remote_task(subject_hash, task, authority, store \\ Store) do
    operation = Intent.operation(task)

    Ex4pm.Evidence.BRCE.execute(
      subject_hash,
      operation,
      authority,
      fn -> Intent.execute(task) end,
      store: store,
      metadata: %{
        distributed: true,
        executing_node: Node.self(),
        task_id: task.id,
        task_label: task.label
      }
    )
  end

  def security_posture do
    transport = distribution_transport()
    encrypted? = transport in [:inet_tls, :inet6_tls]

    %{
      distribution_enabled: Node.alive?(),
      transport: transport,
      encrypted: encrypted?,
      cookie_configured: Node.alive?() and Node.get_cookie() != :nocookie,
      production_network_standing: if(encrypted?, do: :partial_alive, else: :blocked),
      reason:
        if(encrypted?,
          do: :encrypted_distribution_observed_multi_region_unproven,
          else: :plain_distribution_is_not_global_production_security
        )
    }
  end

  defp execute_layers(
         plan,
         authority,
         nodes,
         timeout,
         max_concurrency,
         origin_store,
         remote_store
       ) do
    plan.layers
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, [], []}, fn {layer, layer_index},
                                           {:ok, completed_layers, placements} ->
      work = place_layer(layer, nodes, layer_index)

      results =
        Task.Supervisor.async_stream_nolink(
          Ex4pm.Runtime.TaskSupervisor,
          work,
          fn {task, node} ->
            execute_on_node(
              plan.subject_hash,
              task,
              node,
              authority,
              timeout,
              origin_store,
              remote_store
            )
          end,
          ordered: true,
          max_concurrency: max_concurrency,
          timeout: timeout + 1_000,
          on_timeout: :kill_task
        )
        |> Enum.to_list()

      case normalize_layer_results(results) do
        {:ok, layer_results} ->
          layer_placements = Enum.map(layer_results, &Map.take(&1, [:task_id, :node]))

          {:cont, {:ok, [layer_results | completed_layers], placements ++ layer_placements}}

        {:error, failure} ->
          {:halt,
           {:error,
            %{
              failure: failure,
              completed_layers: Enum.reverse(completed_layers),
              placements: placements
            }}}
      end
    end)
    |> case do
      {:ok, layers, placements} ->
        trace = Enum.reverse(layers)

        {:ok,
         %{
           plan_hash: Ex4pm.Core.Hash.digest(plan),
           subject_hash: plan.subject_hash,
           layers: trace,
           placements: placements,
           nodes: nodes,
           standing: :alive,
           security: security_posture(),
           receipt_hashes: for(layer <- trace, item <- layer, do: item.receipt.hash)
         }}

      error ->
        error
    end
  end

  defp place_layer(layer, nodes, layer_index) do
    node_count = length(nodes)

    layer
    |> Enum.with_index()
    |> Enum.map(fn {task, task_index} ->
      node = Enum.at(nodes, rem(layer_index + task_index, node_count))
      {task, node}
    end)
  end

  defp execute_on_node(subject_hash, task, node, authority, timeout, origin_store, remote_store) do
    try do
      case :erpc.call(
             node,
             __MODULE__,
             :execute_remote_task,
             [subject_hash, task, authority, remote_store],
             timeout
           ) do
        {:ok, %{result: result, pending: pending, receipt: receipt}} ->
          with :ok <- verify_receipt_chain(subject_hash, pending, receipt),
               :ok <- mirror_receipt(pending, origin_store),
               :ok <- mirror_receipt(receipt, origin_store) do
            {:ok,
             %{
               task_id: task.id,
               node: node,
               result: result,
               pending: pending,
               receipt: receipt
             }}
          end

        {:error, %{receipt: receipt} = failure} ->
          _ = mirror_receipt(receipt, origin_store)
          {:error, %{failure: failure, node: node, task_id: task.id}}

        {:error, %Refusal{} = refusal} ->
          {:error, %{failure: refusal, node: node, task_id: task.id}}

        other ->
          {:error,
           Refusal.new(
             :invalid_distributed_task_result,
             "remote runtime returned an unrecognized result",
             details: %{node: node, task_id: task.id, result: inspect(other)}
           )}
      end
    catch
      :error, {:erpc, reason} ->
        {:error, erpc_refusal(reason, node, task, subject_hash)}

      kind, reason ->
        {:error,
         Refusal.new(:distributed_remote_failure, "remote runtime call failed",
           details: %{
             node: node,
             task_id: task.id,
             subject_hash: subject_hash,
             class: kind,
             reason: inspect(reason),
             do_may_have_been_attempted: true
           }
         )}
    end
  end

  defp verify_receipt_chain(subject_hash, pending, receipt) do
    with {:ok, _} <- Replay.verify(pending),
         {:ok, _} <- Replay.verify(receipt),
         true <- pending.subject_hash == subject_hash,
         true <- receipt.subject_hash == subject_hash,
         true <- receipt.parent_hash == pending.hash,
         true <- receipt.operation == pending.operation do
      :ok
    else
      {:error, %Refusal{} = refusal} ->
        {:error, refusal}

      _ ->
        {:error,
         Refusal.new(
           :distributed_receipt_chain_mismatch,
           "remote pending/outcome receipts do not close over the admitted subject"
         )}
    end
  end

  defp mirror_receipt(receipt, store) do
    try do
      case Store.put(receipt, store) do
        {:ok, _} ->
          :ok

        other ->
          {:error,
           Refusal.new(
             :distributed_receipt_mirror_failed,
             "remote receipt could not be mirrored into the origin ledger",
             details: %{receipt_hash: receipt.hash, result: inspect(other), do_attempted: true}
           )}
      end
    catch
      kind, reason ->
        {:error,
         Refusal.new(
           :distributed_receipt_mirror_failed,
           "remote receipt mirror crashed",
           details: %{
             receipt_hash: receipt.hash,
             class: kind,
             reason: inspect(reason),
             do_attempted: true
           }
         )}
    end
  end

  defp normalize_layer_results(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, {:ok, item}}, {:ok, acc} ->
        {:cont, {:ok, [item | acc]}}

      {:ok, {:error, failure}}, _acc ->
        {:halt, {:error, failure}}

      {:exit, reason}, _acc ->
        {:halt,
         {:error,
          Refusal.new(:distributed_driver_exit, "distributed task driver exited",
            details: %{reason: inspect(reason), do_may_have_been_attempted: true}
          )}}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp admit_distribution([]) do
    {:error,
     Refusal.new(
       :distributed_nodes_required,
       "distributed execution requires at least one explicit node"
     )}
  end

  defp admit_distribution(nodes) do
    cond do
      not Node.alive?() ->
        {:error,
         Refusal.new(
           :distribution_not_started,
           "the origin BEAM node is not running Erlang distribution"
         )}

      not Enum.all?(nodes, &is_atom/1) ->
        {:error,
         Refusal.new(:invalid_distributed_nodes, "distributed nodes must be node atoms",
           subject: nodes
         )}

      true ->
        :ok
    end
  end

  defp admit_nodes(nodes) do
    unreachable = Enum.reject(nodes, &(Node.ping(&1) == :pong))

    if unreachable == [] do
      :ok
    else
      {:error,
       Refusal.new(
         :distributed_nodes_unreachable,
         "one or more admitted distributed nodes are unreachable",
         details: %{nodes: unreachable, do_attempted: false}
       )}
    end
  end

  defp erpc_refusal(reason, node, task, subject_hash) do
    ambiguous? = reason in [:noconnection, :timeout]

    code =
      case reason do
        :noconnection -> :distributed_node_connection_lost
        :timeout -> :distributed_task_timeout
        :system_limit -> :distributed_system_limit
        :notsup -> :distributed_erpc_unsupported
        _ -> :distributed_erpc_failed
      end

    Refusal.new(code, "distributed Erlang RPC failed",
      details: %{
        reason: reason,
        node: node,
        task_id: task.id,
        subject_hash: subject_hash,
        do_may_have_been_attempted: ambiguous?
      }
    )
  end

  defp distribution_transport do
    args =
      case :init.get_argument(:proto_dist) do
        {:ok, values} -> List.flatten(values)
        _ -> []
      end

    normalized = Enum.map(args, &to_string/1)

    cond do
      Enum.any?(normalized, &(&1 == "inet_tls")) -> :inet_tls
      Enum.any?(normalized, &(&1 == "inet6_tls")) -> :inet6_tls
      true -> :inet_tcp
    end
  end
end
