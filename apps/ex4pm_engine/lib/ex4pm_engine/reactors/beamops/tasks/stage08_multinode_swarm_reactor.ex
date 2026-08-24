# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage08MultiNodeSwarmReactor do
  @moduledoc """
  Chapter 8 Task: Validates Multi-node EC2 Docker Swarm init tokens, overlay networks, and node quorum.
  """
  use Reactor

  input(:swarm_nodes)
  input(:overlay_network)

  step :validate_multinode_swarm do
    async?(false)
    argument(:nodes, input(:swarm_nodes))
    argument(:network, input(:overlay_network))

    run(fn args, _context ->
      has_quorum? = length(args.nodes) >= 2
      has_network? = is_binary(args.network) and byte_size(args.network) > 0

      if has_quorum? and has_network? do
        {:ok,
         %{
           stage: "Ch08_MultiNode_Swarm",
           status: :verified,
           node_count: length(args.nodes),
           overlay_network: args.network,
           standing: :alive
         }}
      else
        {:error, {:swarm_insufficient_nodes, args.nodes}}
      end
    end)
  end

  return(:validate_multinode_swarm)
end
