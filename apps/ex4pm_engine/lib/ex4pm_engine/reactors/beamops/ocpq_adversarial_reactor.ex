# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.OcpqAdversarialReactor do
  @moduledoc """
  Adversarial OCPQ (Object-Centric Process Querying) validation reactor.
  Extracts multi-object interaction graphs from living cluster/deployment operations
  and evaluates structural & temporal invariants across disjoint object types
  (Deployment, ClusterNode, KanbanCard, MetricProbe).
  """
  use Reactor

  alias Ex4pmEngine.Cognition.Ocpq

  input(:event_log)
  input(:query_tree)
  input(:expected_cardinality)

  step :evaluate_ocpq_invariants do
    async?(false)
    argument(:log, input(:event_log))
    argument(:tree, input(:query_tree))
    argument(:cardinality, input(:expected_cardinality))

    run(fn args, _context ->
      res = Ocpq.evaluate_query(args.log, args.tree)

      min_card = args.cardinality[:min] || 1
      max_card = args.cardinality[:max] || :infinity

      root_bindings = res.total_root_bindings

      satisfied? =
        res.satisfied? and root_bindings >= min_card and
          (max_card == :infinity or root_bindings <= max_card)

      if satisfied? do
        {:ok,
         %{
           ocpq_status: :satisfied,
           bindings_found: root_bindings,
           violations_count: res.violations_count,
           standing: :alive
         }}
      else
        {:error,
         {:ocpq_cardinality_violation,
          %{
            found: if(res.satisfied?, do: root_bindings, else: 0),
            expected: {min_card, max_card}
          }}}
      end
    end)
  end

  step :record_ocpq_receipt do
    async?(false)
    argument(:eval_res, result(:evaluate_ocpq_invariants))

    run(fn args, _context ->
      subject_hash = Ex4pm.Core.Hash.digest("OCPQ:MultiObject:Invariants")
      authority = %{capabilities: [:do], allow: ["ocpq_multi_object_validation"]}

      metadata = %{
        bindings_count: args.eval_res.bindings_found,
        ocpq_status: args.eval_res.ocpq_status
      }

      {:ok, %{receipt: outcome_receipt}} =
        Ex4pm.Evidence.BRCE.execute(
          subject_hash,
          "ocpq_multi_object_validation",
          authority,
          fn ->
            %{
              bindings_count: args.eval_res.bindings_found,
              status: args.eval_res.ocpq_status
            }
          end,
          metadata: metadata
        )

      {:ok, replay_res} = Ex4pm.Evidence.Replay.verify(outcome_receipt)

      {:ok, %{receipt: outcome_receipt, replay: replay_res}}
    end)
  end

  collect :ocpq_bundle do
    argument(:eval_res, result(:evaluate_ocpq_invariants))
    argument(:receipt, result(:record_ocpq_receipt))

    transform(fn inputs ->
      receipt = inputs.receipt.receipt

      %{
        ocpq_status: inputs.eval_res.ocpq_status,
        bindings_found: inputs.eval_res.bindings_found,
        receipt_hash: receipt.hash,
        standing: receipt.standing,
        replay_match?: inputs.receipt.replay.replay == :match
      }
    end)
  end

  return(:ocpq_bundle)
end
