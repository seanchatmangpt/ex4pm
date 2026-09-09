defmodule Ex4pmEngine.WorkflowNetPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Ex4pmEngine.WorkflowNet
  alias Ex4pmEngine.WorkflowNet.SoundnessReport

  @moduletag :property

  property "Linear sequence workflow nets of arbitrary length always pass 1-safe soundness" do
    check all(length <- StreamData.integer(1..12)) do
      places = for i <- 0..length, do: "p_#{i}"
      transitions = for i <- 1..length, do: "t_#{i}"

      arcs =
        Enum.flat_map(1..length, fn i ->
          [
            {"p_#{i - 1}", "t_#{i}"},
            {"t_#{i}", "p_#{i}"}
          ]
        end)

      assert {:ok, net} =
               WorkflowNet.new(places, transitions, arcs,
                 source_place: "p_0",
                 sink_place: "p_#{length}"
               )

      assert {:ok, %SoundnessReport{} = report} = WorkflowNet.verify_soundness(net)
      assert report.sound? == true
      assert report.one_safe? == true
      assert report.option_to_complete? == true
      assert report.proper_completion? == true
      assert report.no_dead_transitions? == true
      assert report.livelock_detected? == false
      assert report.deadlocks == []
    end
  end

  property "Parallel fork-join workflow nets with N symmetric branches always pass 1-safe soundness" do
    check all(branch_count <- StreamData.integer(2..6)) do
      source = "p_start"
      sink = "p_end"
      split_t = "t_split"
      join_t = "t_join"

      branch_transitions = for i <- 1..branch_count, do: "t_work_#{i}"
      all_transitions = [split_t, join_t | branch_transitions]

      p_in_branches = for i <- 1..branch_count, do: "p_in_#{i}"
      p_out_branches = for i <- 1..branch_count, do: "p_out_#{i}"

      canon_places = [source, sink | p_in_branches ++ p_out_branches]

      canon_arcs =
        for(p <- p_in_branches, do: {split_t, p}) ++
          for(p <- p_out_branches, do: {p, join_t}) ++
          Enum.flat_map(1..branch_count, fn i ->
            [
              {"p_in_#{i}", "t_work_#{i}"},
              {"t_work_#{i}", "p_out_#{i}"}
            ]
          end) ++
          [
            {source, split_t},
            {join_t, sink}
          ]

      assert {:ok, net} =
               WorkflowNet.new(canon_places, all_transitions, canon_arcs,
                 source_place: source,
                 sink_place: sink
               )

      assert {:ok, %SoundnessReport{} = report} = WorkflowNet.verify_soundness(net)
      assert report.sound? == true
      assert report.one_safe? == true
      assert report.option_to_complete? == true
      assert report.proper_completion? == true
    end
  end
end
