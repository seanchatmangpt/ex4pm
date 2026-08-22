defmodule Ex4pm.Runtime.Distributed do
  @moduledoc "Evidence-bounded distributed POWL execution scheduled exclusively by Reactor."

  alias Ex4pm.Evidence.{Replay, Store}
  alias Ex4pm.Refusal
  alias Ex4pm.Runtime
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
      placements = placement_map(plan, nodes)

      task_runner = fn task, _runtime_context ->
        node = Map.fetch!(placements, task.id)

        execute_on_node(
          plan.subject_hash,
          task,
          node,
          authority,
          timeout,
          origin_store,
          remote_store
        )
      end

      case Runtime.execute(plan, authority,
             task_runner: task_runner,
             store: origin_store,
             max_concurrency: max_concurrency,
             timeout: timeout
           ) do
        {:ok, execution} -> {:ok, distributed_execution(execution, nodes)}
        {:error, _reason} = error -> error
      end
    end
  end

  def execute(other, _authority, _opts) do
    {:error,
     Refusal.new(:invalid_distributed_execution_plan,
       "distributed execution requires a compiled runtime plan",
       subject: other
     )}
  end

  def execute_remote_task(subject_hash, task, authority, store \\ Store) do
    operation = Intent.operation(task)

    Ex4pm.Evidence.BRCE.execute(subject_hash, operation, authority, fn -> Intent.execute(task) end,
      store: store,
      metadata: %{
        distributed: true,
        executing_node: Node.self(),
        runtime: :reactor,
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

  defp placement_map(plan, nodes) do
    node_count = length(nodes)

    plan.layers
    |> Enum.with_index()
    |> Enum.flat_map(fn {layer, layer_index} ->
      layer
      |> Enum.with_index()
      |> Enum.map(fn {task, task_index} ->
        {task.id, Enum.at(nodes, rem(layer_index + task_index, node_count))}
      end)
    end)
    |> Map.new()
  end

  defp distributed_execution(execution, nodes) do
    layers =
      Enum.map(execution.layers, fn layer ->
        Enum.map(layer, fn item ->
          %{node: node, value: value} = item.result

          %{
            task_id: item.task_id,
            node: node,
            result: value,
            pending: item.pending,
            receipt: item.receipt
          }
        end)
      end)

    placements = for layer <- layers, item <- layer, do: Map.take(item, [:task_id, :node])

    execution
    |> Map.put(:layers, layers)
    |> Map.put(:placements, placements)
    |> Map.put(:nodes, nodes)
    |> Map.put(:runtime, :reactor_distributed)
    |> Map.put(:security, security_posture())
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
               result: %{node: node, value: result},
               pending: pending,
               receipt: receipt
             }}
          end

        {:error, %{pending: pending, receipt: receipt} = failure} ->
          with :ok <- verify_receipt_chain(subject_hash, pending, receipt),
               :ok <- mirror_receipt(pending, origin_store),
               :ok <- mirror_receipt(receipt, origin_store) do
            {:error, %{failure: failure, node: node, task_id: task.id}}
          end

        {:error, %Refusal{} = refusal} ->
          {:error, %{failure: refusal, node: node, task_id: task.id}}

        other ->
          {:error,
           Refusal.new(:invalid_distributed_task_result,
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
         Refusal.new(:distributed_receipt_chain_mismatch,
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
           Refusal.new(:distributed_receipt_mirror_failed,
             "remote receipt could not be mirrored into the origin ledger",
             details: %{receipt_hash: receipt.hash, result: inspect(other), do_attempted: true}
           )}
      end
    catch
      kind, reason ->
        {:error,
         Refusal.new(:distributed_receipt_mirror_failed,
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

  defp admit_distribution([]) do
    {:error,
     Refusal.new(:distributed_nodes_required,
       "distributed execution requires at least one explicit node"
     )}
  end

  defp admit_distribution(nodes) do
    cond do
      not Node.alive?() ->
        {:error,
         Refusal.new(:distribution_not_started,
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
       Refusal.new(:distributed_nodes_unreachable,
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
