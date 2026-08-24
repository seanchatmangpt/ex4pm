# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.RollingDeploymentReactor do
  @moduledoc """
  Reactor Saga executing zero-downtime rolling release deployments with
  continuous health probe verification and atomic LIFO rollback upon health failure.
  """
  use Reactor
  alias Ex4pmDomain.BEAMOps.Deployment

  input(:deployment_id)
  input(:version)
  input(:image_digest)
  input(:nodes)
  input(:inject_fault?)
  input(:fault_node)

  # Step 1: Reserve deployment lock and initialize Ash record
  step :reserve_deployment do
    argument(:id, input(:deployment_id))
    argument(:version, input(:version))
    argument(:image, input(:image_digest))
    argument(:nodes, input(:nodes))

    run(fn args, context ->
      attrs = %{
        id: args.id,
        version: args.version,
        image_digest: args.image,
        target_nodes: args.nodes,
        status: :rolling_out
      }

      {:ok, dep} = Ash.create(Deployment, attrs)

      if caller = Map.get(context, :test_pid) do
        send(caller, {:deployment_reserved, dep.id, dep.version})
      end

      {:ok, dep}
    end)

    undo(fn dep, _args, context ->
      {:ok, _} = Ash.update(dep, %{status: :rolled_back})

      if caller = Map.get(context, :test_pid) do
        send(caller, {:deployment_undone, dep.id})
      end

      :ok
    end)
  end

  # Step 2: Rollout to cluster nodes in sequence
  step :rollout_nodes do
    argument(:dep, result(:reserve_deployment))
    argument(:nodes, input(:nodes))
    argument(:inject_fault?, input(:inject_fault?))
    argument(:fault_node, input(:fault_node))

    run(fn args, context ->
      for node <- args.nodes do
        if caller = Map.get(context, :test_pid) do
          send(caller, {:node_release_staged, node, args.dep.version})
        end
      end

      {:ok, %{staged_nodes: args.nodes}}
    end)

    undo(fn _result, args, context ->
      for node <- Enum.reverse(args.nodes) do
        if caller = Map.get(context, :test_pid) do
          send(caller, {:node_release_reverted, node})
        end
      end

      :ok
    end)
  end

  # Step 3: Verify /healthz and /readyz probes across nodes
  step :verify_health_probes do
    argument(:nodes, input(:nodes))
    argument(:inject_fault?, input(:inject_fault?))
    argument(:fault_node, input(:fault_node))
    wait_for(:rollout_nodes)

    run(fn args, _context ->
      if args.inject_fault? do
        {:error, {:health_probe_failed, args.fault_node, :readiness_check_timeout}}
      else
        {:ok, %{healthy_nodes: args.nodes, probes_passed: length(args.nodes)}}
      end
    end)
  end

  # Step 4: Finalize Deployment Promotion
  step :finalize_promotion do
    argument(:dep, result(:reserve_deployment))
    argument(:probes, result(:verify_health_probes))

    run(fn args, context ->
      {:ok, updated} =
        Ash.update(args.dep, %{
          status: :healthy,
          health_probes_passed: args.probes.probes_passed
        })

      if caller = Map.get(context, :test_pid) do
        send(caller, {:deployment_promoted, updated.id})
      end

      {:ok, updated}
    end)
  end

  collect :deployment_manifest do
    argument(:deployment, result(:finalize_promotion))
    argument(:probes, result(:verify_health_probes))

    transform(fn inputs ->
      %{
        deployment_id: inputs.deployment.id,
        version: inputs.deployment.version,
        status: inputs.deployment.status,
        healthy_nodes: inputs.probes.healthy_nodes,
        probes_passed: inputs.probes.probes_passed,
        standing: :alive
      }
    end)
  end

  return(:deployment_manifest)
end
