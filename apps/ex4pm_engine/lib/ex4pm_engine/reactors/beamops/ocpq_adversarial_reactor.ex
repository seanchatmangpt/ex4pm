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

  alias Ex4pmDomain.Receipt
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
      receipt_hash =
        :crypto.hash(
          :sha256,
          "ReceiptSealed:OCPQ:#{System.unique_integer([:positive])}"
        )
        |> Base.encode16(case: :lower)

      {:ok, receipt} =
        Ash.create(Receipt, %{
          hash: receipt_hash,
          phase: :completed,
          operation: "ocpq_multi_object_validation",
          subject_hash:
            :crypto.hash(:sha256, "OCPQ:MultiObject:Invariants")
            |> Base.encode16(case: :lower),
          agent_id: "agent_ocpq_adversary_01",
          run_id: "run_ocpq_01",
          standing: :alive,
          started_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          finished_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          metadata: %{
            "bindings_count" => args.eval_res.bindings_found,
            "ocpq_status" => to_string(args.eval_res.ocpq_status)
          }
        })

      {:ok, receipt}
    end)
  end

  collect :ocpq_bundle do
    argument(:eval_res, result(:evaluate_ocpq_invariants))
    argument(:receipt, result(:record_ocpq_receipt))

    transform(fn inputs ->
      %{
        ocpq_status: inputs.eval_res.ocpq_status,
        bindings_found: inputs.eval_res.bindings_found,
        receipt_id: inputs.receipt.id,
        receipt_hash: inputs.receipt.hash,
        standing: :alive
      }
    end)
  end

  return(:ocpq_bundle)
end
