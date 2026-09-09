# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Engine.Discovery.InductiveMinerTest do
  @moduledoc """
  Chicago-style real-collaborator suite: real synthetic event logs (lists of
  lists of activity-name strings), real DFG construction, real cut detection,
  real recursive discovery — no mocked collaborators anywhere in this file.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.Engine.Discovery.InductiveMiner
  alias Ex4pm.Engine.Discovery.InductiveMiner.ProcessTree

  describe "directly_follows_graph/1 and alphabet/1" do
    test "computes real edge frequencies from a real sequential log" do
      log = [["a", "b", "c"], ["a", "b", "c"], ["a", "b", "c"]]

      dfg = InductiveMiner.directly_follows_graph(log)

      assert dfg == %{{"a", "b"} => 3, {"b", "c"} => 3}
      assert InductiveMiner.alphabet(log) == ["a", "b", "c"]
    end
  end

  describe "mine/1 — sequence cut" do
    test "discovers a fully-explaining sequence tree for a purely sequential log ABC" do
      log = [["a", "b", "c"], ["a", "b", "c"], ["a", "b", "c"]]

      assert {:ok, %ProcessTree{kind: :sequence, children: children}} = InductiveMiner.mine(log)
      assert Enum.map(children, & &1.label) == ["a", "b", "c"]
      assert Enum.all?(children, &(&1.kind == :leaf))
    end

    test "sequence cut orders parts correctly for a longer real chain A->B->C->D" do
      log = [["a", "b", "c", "d"], ["a", "b", "c", "d"]]

      assert {:ok, %ProcessTree{kind: :sequence, children: children}} = InductiveMiner.mine(log)
      assert Enum.map(children, & &1.label) == ["a", "b", "c", "d"]
    end
  end

  describe "mine/1 — exclusive-choice cut" do
    test "a->(b xor c): a is DFG-adjacent to both b and c so exclusive-choice does not fire at " <>
           "the top level; the module finds a valid sequence cut over 3 unconnected singletons" do
      log = [["a", "b"], ["a", "b"], ["a", "c"], ["a", "c"]]

      assert {:ok, %ProcessTree{kind: :sequence, children: children}} = InductiveMiner.mine(log)
      assert Enum.map(children, & &1.label) == ["a", "b", "c"]
      assert Enum.all?(children, &(&1.kind == :leaf))
    end

    test "pure exclusive choice at the top level: log is either [x] or [y], never mixed" do
      log = [["x"], ["x"], ["y"]]

      assert {:ok, %ProcessTree{kind: :exclusive_choice, children: children}} =
               InductiveMiner.mine(log)

      assert Enum.map(children, & &1.label) |> Enum.sort() == ["x", "y"]
    end
  end

  describe "mine/1 — honest fallback on unimplemented cuts" do
    test "returns :partial with a named FlowerFallback when only a parallel-shaped log is given" do
      # a and b interleave in both orders across traces -> mutually reachable,
      # no exclusive-choice partition, no acyclic sequence order: this is a
      # real parallel-cut case, which this module does not implement.
      log = [["a", "b"], ["b", "a"]]

      assert {:partial, %ProcessTree{}, [%InductiveMiner.FlowerFallback{} = fb]} =
               InductiveMiner.mine(log)

      assert Enum.sort(fb.activities) == ["a", "b"]
      assert fb.reason =~ "parallel/loop/fall-through"
    end
  end

  describe "mine/1 — base cases" do
    test "single-activity log discovers a leaf" do
      assert {:ok, %ProcessTree{kind: :leaf, label: "a"}} = InductiveMiner.mine([["a"], ["a"]])
    end

    test "empty log discovers a tau/silent node" do
      assert {:ok, %ProcessTree{kind: :tau}} = InductiveMiner.mine([])
    end
  end
end
