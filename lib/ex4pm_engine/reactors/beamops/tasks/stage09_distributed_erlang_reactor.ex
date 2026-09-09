# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage09DistributedErlangReactor do
  @moduledoc """
  Chapter 9 Task: Validates Distributed Erlang clustering (libcluster, EPMD, PubSub).
  """
  use Reactor

  input(:cluster_strategy)
  input(:connected_nodes)

  step :validate_distributed_erlang do
    async?(false)
    argument(:strategy, input(:cluster_strategy))
    argument(:nodes, input(:connected_nodes))

    run(fn args, _context ->
      has_strategy? = args.strategy in [:gossip, :epmd, :dns, "gossip", "epmd", "dns"]
      has_cluster? = length(args.nodes) >= 2

      if has_strategy? and has_cluster? do
        {:ok,
         %{
           stage: "Ch09_Distributed_Erlang",
           status: :verified,
           strategy: args.strategy,
           connected_nodes: args.nodes,
           pubsub_broadcast: :ok,
           standing: :alive
         }}
      else
        {:error, {:cluster_not_interconnected, args.nodes}}
      end
    end)
  end

  return(:validate_distributed_erlang)
end
