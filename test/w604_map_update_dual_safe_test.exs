# W604 regression: dual-safe idiom at the 35 absent-key-reliant `Map.update/4` sites
# (w525d census, ex4pm leg). Pins OBSERVED runtime behavior:
#   absent key  -> store default WITHOUT calling update-fun (this runtime skips fun)
#   present key -> store fun(value)   (both runtimes agree)
# The dual-safe case/fetch idiom encodes this explicitly. The canary below fails
# loudly if the toolchain deviation is fixed without re-review of these sites.

defmodule W604MapUpdateDualSafeTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Engine.Discovery.InductiveMiner
  alias Ex4pm.Explore.Markov
  alias Ex4pm.Explore.ObjectEvent
  alias Ex4pm.Explore.VectorClock
  alias Ex4pmCore.ProcessIR

  test "canary: Map.update/4 skips fun on absent key on this runtime" do
    assert Map.update(%{}, :k, 7, &(&1 + 1)) == %{k: 7}
  end

  test "VectorClock.tick/2: absent key seeds 1, present key increments" do
    clock = VectorClock.tick(%{}, :a)
    assert clock == %{a: 1}

    assert VectorClock.tick(clock, :a) == %{a: 2}
  end

  test "ObjectEvent.index/1: absent key seeds [event], present appends in order" do
    e1 = %{objects: [:x], id: 1}
    e2 = %{objects: [:x], id: 2}
    e3 = %{objects: [:x], id: 3}

    index = ObjectEvent.index([e1, e2, e3])
    assert index == %{x: [e1, e2, e3]}
  end

  test "Markov.fit/1: totals reduced over per-edge counts (totals seeding exercised)" do
    # totals reducer: absent key stores count, present key adds count. The output
    # probabilities are totals-invariant, so pin exact output equality.
    assert Markov.fit([{:a, :b}, {:a, :b}, {:a, :c}]) ==
             %{{:a, :b} => 2 / 3, {:a, :c} => 1 / 3}
  end

  test "InductiveMiner.directly_follows_graph/1: first edge occurrence counts 1" do
    dfg = InductiveMiner.directly_follows_graph([["a", "b", "b", "c"]])
    assert dfg == %{{"a", "b"} => 1, {"b", "b"} => 1, {"b", "c"} => 1}
  end

  # ---- suspect-site pins ---------------------------------------------------

  test "SUSPECT pin inductive_miner do_kahn: sequence log yields ordered sequence tree" do
    # Exercises kahn_sort/do_kahn (line 327 decrement) via the sequence cut path.
    assert {:ok, tree} = InductiveMiner.mine([["a", "b", "c"]])
    assert tree.kind == :sequence
    labels =
      Enum.map(tree.children, fn
        %InductiveMiner.ProcessTree{kind: :leaf, label: l} -> l
        _ -> :subtree
      end)

    assert labels == ["a", "b", "c"]
  end

  test "SUSPECT pin process_ir consume_dag: acyclic PO ok, cyclic PO refused" do
    ok_attrs = %{
      id: "w604_dag_ok",
      activities: [%{id: "a"}, %{id: "b"}, %{id: "c"}],
      partial_orders: [
        %{id: "po", nodes: ["a", "b", "c"], edges: [{"a", "b"}, {"b", "c"}]}
      ]
    }

    assert {:ok, ir} = ProcessIR.new(ok_attrs)
    assert map_size(ir.partial_orders) == 1

    cyclic = %{
      id: "w604_dag_cyclic",
      activities: [%{id: "a"}, %{id: "b"}],
      partial_orders: [
        %{id: "po", nodes: ["a", "b"], edges: [{"a", "b"}, {"b", "a"}]}
      ]
    }

    assert {:error, %Ex4pm.Refusal{code: :cyclic_partial_order}} = ProcessIR.new(cyclic)
  end

  test "SUSPECT pin process_ir consume_dag: shared-successor multi-edge DAG" do
    # Two parents sharing the same successor: the decrement branch runs twice on a
    # present key — guards the v - 1 path (never a 0-seeded -1).
    attrs = %{
      id: "w604_dag_diamond",
      activities: [%{id: "a"}, %{id: "b"}, %{id: "c"}, %{id: "d"}],
      partial_orders: [
        %{id: "po", nodes: ["a", "b", "c", "d"], edges: [{"a", "c"}, {"b", "c"}, {"c", "d"}]}
      ]
    }

    assert {:ok, _ir} = ProcessIR.new(attrs)
  end
end
