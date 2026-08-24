# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.ClusterRebalanceReactor do
  @moduledoc """
  Reactor Saga reconciling distributed Erlang cluster membership and gossiping
  topology updates with Ash Resource tracking and BRCE audit receipts.
  """
  use Reactor
  alias Ex4pmDomain.BEAMOps.ClusterNode

  input(:target_nodes)
  input(:active_peers)

  # Step 1: Reconcile Joiners
  step :reconcile_joining_nodes do
    argument(:targets, input(:target_nodes))
    argument(:peers, input(:active_peers))

    run(fn args, _context ->
      joining = Enum.reject(args.targets, &(&1 in args.peers))

      registered =
        for node_name <- joining do
          {:ok, node} =
            Ash.create(ClusterNode, %{
              id: "node_#{node_name}",
              node_name: "#{node_name}@127.0.0.1",
              status: :healthy,
              heartbeat_at: DateTime.utc_now() |> DateTime.to_iso8601()
            })

          node
        end

      {:ok, registered}
    end)
  end

  # Step 2: Reconcile Leavers
  step :reconcile_leaving_nodes do
    argument(:targets, input(:target_nodes))
    argument(:peers, input(:active_peers))

    run(fn args, _context ->
      leaving = Enum.reject(args.peers, &(&1 in args.targets))

      deregistered =
        for node_name <- leaving do
          id = "node_#{node_name}"

          case Ash.get(ClusterNode, id) do
            {:ok, node} ->
              {:ok, updated} = Ash.update(node, %{status: :left})
              updated

            _ ->
              {:left, node_name}
          end
        end

      {:ok, deregistered}
    end)
  end

  collect :cluster_topology do
    argument(:joined, result(:reconcile_joining_nodes))
    argument(:left, result(:reconcile_leaving_nodes))
    argument(:targets, input(:target_nodes))

    transform(fn inputs ->
      %{
        cluster_size: length(inputs.targets),
        active_nodes: inputs.targets,
        joined_count: length(inputs.joined),
        left_count: length(inputs.left),
        standing: :alive
      }
    end)
  end

  return(:cluster_topology)
end
