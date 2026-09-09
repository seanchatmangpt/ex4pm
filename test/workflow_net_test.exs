defmodule Ex4pmEngine.WorkflowNetTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Refusal
  alias Ex4pmEngine.WorkflowNet
  alias Ex4pmEngine.WorkflowNet.{SoundnessReport, Transition}

  test "sound sequence workflow net validates Definition 3.3 and passes 1-safe soundness" do
    places = ["p_in", "p1", "p_out"]
    transitions = ["t1", "t2"]

    arcs = [
      {"p_in", "t1"},
      {"t1", "p1"},
      {"p1", "t2"},
      {"t2", "p_out"}
    ]

    assert {:ok, net} = WorkflowNet.new(places, transitions, arcs)
    assert :ok = WorkflowNet.validate_structure(net)

    assert {:ok, %SoundnessReport{} = report} = WorkflowNet.verify_soundness(net)
    assert report.sound? == true
    assert report.definition_3_3_valid? == true
    assert report.one_safe? == true
    assert report.option_to_complete? == true
    assert report.proper_completion? == true
    assert report.no_dead_transitions? == true
    assert report.deadlocks == []
    assert report.livelock_detected? == false
    assert report.reachable_markings_count == 3
  end

  test "sound parallel (AND fork-join) net passes 1-safe soundness" do
    places = ["i", "p1", "p2", "p1_done", "p2_done", "o"]
    transitions = ["t_split", "t_a", "t_b", "t_join"]

    arcs = [
      {"i", "t_split"},
      {"t_split", "p1"},
      {"t_split", "p2"},
      {"p1", "t_a"},
      {"p2", "t_b"},
      {"t_a", "p1_done"},
      {"t_b", "p2_done"},
      {"p1_done", "t_join"},
      {"p2_done", "t_join"},
      {"t_join", "o"}
    ]

    assert {:ok, net} = WorkflowNet.new(places, transitions, arcs)
    assert {:ok, report} = WorkflowNet.verify_soundness(net)
    assert report.sound? == true
    assert report.one_safe? == true
    assert report.option_to_complete? == true
  end

  test "sound XOR choice and loop net passes soundness" do
    places = ["i", "p_choice", "p_loop", "o"]
    transitions = ["t_in", "t_branch1", "t_redo", "t_out"]

    arcs = [
      {"i", "t_in"},
      {"t_in", "p_choice"},
      {"p_choice", "t_branch1"},
      {"t_branch1", "p_loop"},
      {"p_loop", "t_redo"},
      {"t_redo", "p_choice"},
      {"p_loop", "t_out"},
      {"t_out", "o"}
    ]

    assert {:ok, net} = WorkflowNet.new(places, transitions, arcs)
    assert {:ok, report} = WorkflowNet.verify_soundness(net)
    assert report.sound? == true
    assert report.option_to_complete? == true
  end

  test "detects Definition 3.3 structural violations (disconnected node, multiple sources/sinks)" do
    # Disconnected place
    places = ["i", "p1", "p_disconnected", "o"]
    transitions = ["t1", "t2"]

    arcs = [
      {"i", "t1"},
      {"t1", "p1"},
      {"p1", "t2"},
      {"t2", "o"}
    ]

    assert {:error, %Refusal{code: :invalid_workflow_net_structure}} =
             WorkflowNet.new(places, transitions, arcs)

    # Multiple sources
    places_multi_src = ["i1", "i2", "o"]
    transitions_multi = ["t1", "t2"]

    arcs_multi = [
      {"i1", "t1"},
      {"i2", "t2"},
      {"t1", "o"},
      {"t2", "o"}
    ]

    assert {:error, %Refusal{code: :invalid_workflow_net_structure}} =
             WorkflowNet.new(places_multi_src, transitions_multi, arcs_multi)
  end

  test "detects deadlock violation (improper synchronization / asymmetric fork)" do
    # Fork into p1 only, but join requires p1 and p2 (which never receives token)
    places = ["i", "p1", "p2", "p3", "o"]
    transitions = ["t_split", "t_dead", "t_join", "t_out"]

    arcs = [
      {"i", "t_split"},
      {"t_split", "p1"},
      {"i", "t_dead"},
      {"t_dead", "p2"},
      {"p1", "t_join"},
      {"p2", "t_join"},
      {"t_join", "p3"},
      {"p3", "t_out"},
      {"t_out", "o"}
    ]

    assert {:ok, net} = WorkflowNet.new(places, transitions, arcs)
    assert {:error, %SoundnessReport{} = report} = WorkflowNet.verify_soundness(net)
    assert report.sound? == false
    assert report.deadlocks != [] or report.dead_transitions != []
  end

  test "detects improper completion (token left behind in place)" do
    # When sink is reached, p_extra also has a token
    places = ["i", "p1", "p_extra", "o"]
    transitions = ["t_split", "t_done", "t_drain"]

    arcs = [
      {"i", "t_split"},
      {"t_split", "p1"},
      {"t_split", "p_extra"},
      {"p1", "t_done"},
      {"t_done", "o"},
      # Extra path to satisfy Def 3.3 structural connectedness
      {"p_extra", "t_drain"},
      {"t_drain", "o"}
    ]

    assert {:ok, net} = WorkflowNet.new(places, transitions, arcs)
    assert {:error, %SoundnessReport{} = report} = WorkflowNet.verify_soundness(net)
    assert report.sound? == false
    assert report.proper_completion? == false
  end

  test "detects livelock (unreachable terminal sink from active loop)" do
    # Choice leads to trap loop with no exit to sink
    places = ["i", "p_branch", "p_trap1", "p_trap2", "p_ok", "o"]
    transitions = ["t_in", "t_to_trap", "t_trap_a", "t_trap_b", "t_to_ok", "t_finish"]

    arcs = [
      {"i", "t_in"},
      {"t_in", "p_branch"},
      {"p_branch", "t_to_trap"},
      {"t_to_trap", "p_trap1"},
      {"p_trap1", "t_trap_a"},
      {"t_trap_a", "p_trap2"},
      {"p_trap2", "t_trap_b"},
      {"t_trap_b", "p_trap1"},
      {"p_branch", "t_to_ok"},
      {"t_to_ok", "p_ok"},
      {"p_ok", "t_finish"},
      {"t_finish", "o"}
    ]

    assert {:ok, net} = WorkflowNet.new(places, transitions, arcs, validate_structure: false)
    assert {:error, %SoundnessReport{} = report} = WorkflowNet.verify_soundness(net)
    assert report.sound? == false
    assert report.option_to_complete? == false
  end

  test "fires transitions and simulates observable traces" do
    places = ["i", "p1", "o"]

    transitions = [
      %Transition{id: "t1", label: "order_created"},
      %Transition{id: "t2", label: "order_shipped"}
    ]

    arcs = [
      {"i", "t1"},
      {"t1", "p1"},
      {"p1", "t2"},
      {"t2", "o"}
    ]

    assert {:ok, net} = WorkflowNet.new(places, transitions, arcs)
    assert WorkflowNet.enabled_transitions(net, %{"i" => 1}) == ["t1"]

    assert {:ok, marking1} = WorkflowNet.fire(net, %{"i" => 1}, "t1")
    assert marking1 == %{"p1" => 1}

    assert {:ok, marking2} = WorkflowNet.fire(net, marking1, "t2")
    assert marking2 == %{"o" => 1}

    assert {:ok, traces} = WorkflowNet.simulate_traces(net)
    assert traces == [["order_created", "order_shipped"]]
  end
end
