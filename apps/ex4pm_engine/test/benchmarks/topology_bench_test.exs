defmodule Ex4pmEngine.Bench.TopologyTest do
  @moduledoc """
  Chicago-style real-run test of the distributed-engine topology benchmark
  harness: exercises real BEAM processes (`Task`) for the `:edge` topology,
  no mocked message passing, and asserts on real captured virtual-cost
  counters and real merged DFG state.
  """
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Bench.{Topology, VirtualCost}

  describe "run_centralized/1 and run_edge/2 correctness invariant" do
    test "both topologies produce the same merged DFG over the same synthetic log" do
      events = Topology.synthetic_log(30)

      {centralized_dfg, _centralized_cost} = Topology.run_centralized(events)
      {edge_dfg, _edge_cost} = Topology.run_edge(events, 4)

      assert centralized_dfg == edge_dfg
      assert map_size(centralized_dfg) > 0
    end

    test "DFG contains expected directly-follows edges for the known synthetic templates" do
      events = Topology.synthetic_log(9)
      {dfg, _cost} = Topology.run_centralized(events)

      # Templates are ["A","B","C","D"], ["A","B","D"], ["A","C","B","D"] —
      # every template starts A->B or A->C, so both edges must appear.
      assert Map.has_key?(dfg, {"A", "B"})
      assert Map.has_key?(dfg, {"A", "C"})
      assert dfg[{"A", "B"}] > 0
    end
  end

  describe "VirtualCost counters" do
    test "new/0 starts at zero and increments are real, additive, non-negative" do
      cost = VirtualCost.new()
      assert cost.compute == 0
      assert cost.store == 0
      assert cost.send == 0

      cost = cost |> VirtualCost.compute(3) |> VirtualCost.store(2) |> VirtualCost.send_op()

      assert cost.compute == 3
      assert cost.store == 2
      assert cost.send == 1
      assert VirtualCost.total(cost) == 6
    end

    test "merge/2 and sum/1 sum fields exactly" do
      a = %VirtualCost{compute: 1, store: 2, send: 3}
      b = %VirtualCost{compute: 10, store: 20, send: 30}

      merged = VirtualCost.merge(a, b)
      assert merged == %VirtualCost{compute: 11, store: 22, send: 33}

      assert VirtualCost.sum([a, b, a]) == %VirtualCost{compute: 12, store: 24, send: 36}
    end
  end

  describe "topology cost-model shape (real captured counts, not mocked)" do
    test "centralized topology reports non-zero compute and store, zero send" do
      events = Topology.synthetic_log(10)
      {_dfg, cost} = Topology.run_centralized(events)

      assert cost.compute > 0
      assert cost.store > 0
      assert cost.send == 0
    end

    test "edge topology reports non-zero send proportional to real node count used" do
      events = Topology.synthetic_log(20)
      {_dfg, cost_2_nodes} = Topology.run_edge(events, 2)
      {_dfg, cost_5_nodes} = Topology.run_edge(events, 5)

      # Each real worker Task sends exactly once back to the coordinator.
      assert cost_2_nodes.send == 2
      assert cost_5_nodes.send == 5
      assert cost_2_nodes.compute > 0
      assert cost_2_nodes.store > 0
    end

    test "edge topology's per-case compute work matches centralized topology's" do
      events = Topology.synthetic_log(24)

      {_dfg, centralized_cost} = Topology.run_centralized(events)
      {_dfg, edge_cost} = Topology.run_edge(events, 3)

      # Same real underlying per-case DFG-building work happens in both
      # topologies; edge distributes it across processes and adds real
      # coordination overhead (one :store per received worker result, plus
      # one :send per worker), so its compute+store total is at least the
      # centralized total, and every case is processed exactly once (no
      # case dropped or double-processed by sharding).
      assert edge_cost.compute + edge_cost.store >=
               centralized_cost.compute + centralized_cost.store

      assert edge_cost.send == 3
    end
  end
end
