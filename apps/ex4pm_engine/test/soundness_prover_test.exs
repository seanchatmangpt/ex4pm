defmodule Ex4pm.Engine.SoundnessProverTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.SoundnessProver

  test "formally proves 1-safe soundness on a valid sequence and parallel fork-join net" do
    # 1. Sound Sequence Net
    sequence_net = %{
      transitions: %{
        t1: %{inputs: ["p_in"], outputs: ["p_1"]},
        t2: %{inputs: ["p_1"], outputs: ["p_2"]},
        t3: %{inputs: ["p_2"], outputs: ["p_out"]}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    report1 = SoundnessProver.verify_soundness(sequence_net)
    assert report1.sound? == true
    assert report1.option_to_complete? == true
    assert report1.proper_completion? == true
    assert report1.no_dead_transitions? == true
    assert report1.one_safe? == true
    assert report1.deadlocks == []

    # 2. Sound Parallel Fork-Join Net
    fork_join_net = %{
      transitions: %{
        fork: %{inputs: ["p_in"], outputs: ["p_a", "p_b"]},
        t_a: %{inputs: ["p_a"], outputs: ["p_done_a"]},
        t_b: %{inputs: ["p_b"], outputs: ["p_done_b"]},
        join: %{inputs: ["p_done_a", "p_done_b"], outputs: ["p_out"]}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    report2 = SoundnessProver.verify_soundness(fork_join_net)
    assert report2.sound? == true
    assert report2.one_safe? == true
    assert report2.reachable_markings_count == 6
  end

  test "detects deadlocks in asymmetric synchronization nets" do
    # Defective Net: fork produces p_a and p_b, but join expects p_a and p_c (p_c is never produced!)
    deadlocked_net = %{
      transitions: %{
        fork: %{inputs: ["p_in"], outputs: ["p_a", "p_b"]},
        t_a: %{inputs: ["p_a"], outputs: ["p_done_a"]},
        join: %{inputs: ["p_done_a", "p_c"], outputs: ["p_out"]}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    report = SoundnessProver.verify_soundness(deadlocked_net)
    assert report.sound? == false
    assert report.option_to_complete? == false
    assert length(report.deadlocks) > 0
    assert "join" in Enum.map(report.dead_transitions, &to_string/1)
  end

  test "detects improper completion and lingering unconsumed tokens" do
    # Defective Net: fork produces p_a and p_b, but finish consumes only p_a, leaving lingering token on p_b
    lingering_net = %{
      transitions: %{
        fork: %{inputs: ["p_in"], outputs: ["p_a", "p_b"]},
        finish: %{inputs: ["p_a"], outputs: ["p_out"]}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    report = SoundnessProver.verify_soundness(lingering_net)
    assert report.sound? == false
    assert report.proper_completion? == false
    assert Enum.any?(report.counterexamples, fn {type, _} -> type == :unconsumed_tokens end)
  end
end
