defmodule Ex4pm.Engine.PowlTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.SoundnessProver

  test "constructs sound-by-construction sequence, choice, and loop POWL trees" do
    # 1. Sequence: A -> B -> C
    tree_seq =
      POWL.sequence("seq_1", [
        POWL.activity("a", "Request"),
        POWL.activity("b", "Approve"),
        POWL.activity("c", "Deploy")
      ])

    net_seq = POWL.to_workflow_net(tree_seq)
    report_seq = SoundnessProver.verify_soundness(net_seq)
    assert report_seq.sound? == true
    assert report_seq.one_safe? == true

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
    report_choice = SoundnessProver.verify_soundness(net_choice)
    assert report_choice.sound? == true

    # 3. Loop: Body(Develop) -> Redo(FixBug)
    tree_loop =
      POWL.loop("loop_1", POWL.activity("body", "Develop"), POWL.activity("redo", "FixBug"))

    net_loop = POWL.to_workflow_net(tree_loop)
    report_loop = SoundnessProver.verify_soundness(net_loop)
    assert report_loop.sound? == true
  end

  test "constructs partially ordered workflow node with explicit precedence constraint" do
    # Partial Order over {A, B, C} where A < B and A < C (B and C execute concurrently after A)
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
    report_po = SoundnessProver.verify_soundness(net_po)
    assert report_po.sound? == true
  end
end
