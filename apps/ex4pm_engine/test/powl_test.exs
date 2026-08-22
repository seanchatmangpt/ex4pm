# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Engine.PowlTest do
  use ExUnit.Case, async: true
  doctest Ex4pmEngine.POWL.ChoiceGraph
  doctest Ex4pmEngine.POWL.Shuffle

  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.POWL.ChoiceGraph
  alias Ex4pmEngine.POWL.Shuffle
  alias Ex4pmEngine.SoundnessProver
  alias Ex4pmEngine.WorkflowNet.Composition

  describe "BPM 2025: Definition 1, 2, 3 Choice Graph Formalism" do
    test "Order-to-Delivery Process: Figure 2b [BPM25, p. 4] non-block-structured choice graph" do
      # Running example: Non-block decision between credit check, express vs regular shipping, and insurance
      t_check = POWL.activity("check", "CheckCredit")
      t_express = POWL.activity("express", "ExpressShip")
      t_regular = POWL.activity("regular", "RegularShip")
      t_insure = POWL.activity("insure", "AddInsurance")
      t_deliver = POWL.activity("deliver", "Deliver")

      # Construct choice graph with ▷ and □
      {:ok, cg} =
        ChoiceGraph.new(
          [t_check, t_express, t_regular, t_insure, t_deliver],
          [
            {"▷", "check"},
            {"check", "express"},
            {"check", "regular"},
            {"express", "insure"},
            {"express", "deliver"},
            {"regular", "deliver"},
            {"insure", "deliver"},
            {"deliver", "□"}
          ]
        )

      paths = ChoiceGraph.enumerate_paths(cg) |> Enum.sort()

      # Valid execution paths:
      # 1. check -> express -> insure -> deliver
      # 2. check -> express -> deliver
      # 3. check -> regular -> deliver
      assert paths == [
               ["check", "express", "deliver"],
               ["check", "express", "insure", "deliver"],
               ["check", "regular", "deliver"]
             ]

      # Compile to WF-net per Section 4.1 [BPM25 p. 9] and assert mathematical soundness
      cg_node = POWL.choice_graph("cg_order", [t_check, t_express, t_regular, t_insure, t_deliver], cg.edges)
      net = POWL.to_workflow_net(cg_node)
      report = SoundnessProver.verify_soundness(net)

      assert report.sound? == true
      assert report.one_safe? == true
      assert report.dead_transitions == []
    end

    test "refuses choice graph violating Definition 1 [BPM25, p. 7] (disconnected orphan node)" do
      a = POWL.activity("a", "TaskA")
      orphan = POWL.activity("orphan", "OrphanTask")

      assert {:error, reason} = ChoiceGraph.new([a, orphan], [{"▷", "a"}, {"a", "□"}])
      assert reason =~ "nodes not on connected path ▷ → n → □"
    end

    test "refuses choice graph violating unique start node {▷} (incoming edge to ▷)" do
      a = POWL.activity("a", "TaskA")

      assert {:error, reason} = ChoiceGraph.new([a], [{"▷", "a"}, {"a", "▷"}, {"a", "□"}])
      assert reason =~ "unique start node condition violated"
    end

    test "refuses choice graph violating unique end node {□} (outgoing edge from □)" do
      a = POWL.activity("a", "TaskA")

      assert {:error, reason} = ChoiceGraph.new([a], [{"▷", "a"}, {"a", "□"}, {"□", "a"}])
      assert reason =~ "unique end node condition violated"
    end
  end

  describe "PETRI NETS 2025: Definition 3.8 Order-Preserving Shuffle Operator (≺⊙)" do
    test "Section 3.1 [BPM25 p. 6] & Definition 3.8 [PETRI25 p. 10] exact example" do
      s1 = ["a", "b"]
      s2 = ["c"]
      s3 = ["d", "e"]
      poset = [{1, 2}, {1, 3}]

      interleavings = Shuffle.op_shuffle([s1, s2, s3], poset)

      assert length(interleavings) == 3
      assert ["a", "b", "c", "d", "e"] in interleavings
      assert ["a", "b", "d", "c", "e"] in interleavings
      assert ["a", "b", "d", "e", "c"] in interleavings
    end
  end

  describe "PETRI NETS 2025: Definition 3.12 Substitutive Composition N[t → N']" do
    test "substitutes transition with sound sub-net preserving SESE boundaries" do
      # Target net N: Start -> t_work -> End
      n = POWL.to_workflow_net(POWL.activity("work", "WorkTask"))

      # Subnet N': Start -> A -> B -> End
      n_prime =
        POWL.to_workflow_net(
          POWL.sequence("seq_sub", [
            POWL.activity("sub_a", "SubTaskA"),
            POWL.activity("sub_b", "SubTaskB")
          ])
        )

      target_t = Enum.find(Map.keys(n.transitions), &(&1 =~ "t_work"))

      assert {:ok, composed_net} = Composition.substitute(n, target_t, n_prime)
      report = SoundnessProver.verify_soundness(composed_net)

      assert report.sound? == true
      assert report.one_safe? == true
    end
  end

  describe "POWL 2.0 Operator Soundness Matrix" do
    test "constructs sound sequence, choice, loop, and partial_order trees" do
      # 1. Sequence: A -> B -> C
      tree_seq =
        POWL.sequence("seq_1", [
          POWL.activity("a", "Request"),
          POWL.activity("b", "Approve"),
          POWL.activity("c", "Deploy")
        ])

      net_seq = POWL.to_workflow_net(tree_seq)
      assert SoundnessProver.verify_soundness(net_seq).sound? == true

      # 2. Choice: A -> (B OR C) -> D
      tree_choice =
        POWL.sequence("seq_2", [
          POWL.activity("a", "Request"),
          POWL.choice("ch_1", [
            POWL.activity("b", "FastTrackApproval"),
            POWL.activity("c", "StandardCABApproval")
          ]),
          POWL.activity("d", "Deploy")
        ])

      net_choice = POWL.to_workflow_net(tree_choice)
      assert SoundnessProver.verify_soundness(net_choice).sound? == true

      # 3. Loop: Body(Develop) -> Redo(FixBug)
      tree_loop =
        POWL.loop("loop_1", POWL.activity("body", "Develop"), POWL.activity("redo", "FixBug"))

      net_loop = POWL.to_workflow_net(tree_loop)
      assert SoundnessProver.verify_soundness(net_loop).sound? == true

      # 4. Partial Order: A < B and A < C
      tree_po =
        POWL.partial_order(
          "po_1",
          [
            POWL.activity("a", "StartTask"),
            POWL.activity("b", "ParallelTaskB"),
            POWL.activity("c", "ParallelTaskC")
          ],
          [{"a", "b"}, {"a", "c"}]
        )

      net_po = POWL.to_workflow_net(tree_po)
      assert SoundnessProver.verify_soundness(net_po).sound? == true
    end
  end
end
