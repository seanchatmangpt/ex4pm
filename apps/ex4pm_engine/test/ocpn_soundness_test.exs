defmodule Ex4pmEngine.OCPNSoundnessTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.OCPN
  alias Ex4pmEngine.OCPN.SoundnessEngine

  describe "OCPN Soundness & Reachability Engine" do
    test "verifies a sound Workflow Net with zero dead transitions and proper completion" do
      net =
        OCPN.new("sound_order_process", ["Order"])
        |> OCPN.add_place("p_start", "Order", initial: true)
        |> OCPN.add_place("p_paid", "Order")
        |> OCPN.add_place("p_end", "Order", terminal: true)
        |> OCPN.add_transition("t_pay", "Pay", ["Order"])
        |> OCPN.add_transition("t_ship", "Ship", ["Order"])
        |> OCPN.add_arc("p_start", "t_pay", "Order")
        |> OCPN.add_arc("t_pay", "p_paid", "Order")
        |> OCPN.add_arc("p_paid", "t_ship", "Order")
        |> OCPN.add_arc("t_ship", "p_end", "Order")

      assert {:ok, result} = SoundnessEngine.verify_reachability(net, "Order")
      assert result.sound? == true
      assert result.terminal_reachable? == true
      assert result.dead_transitions == []
    end

    test "detects reachable deadlock and emits minimal counter-example trace" do
      # An unsound net with parallel split into two places, but an exclusive join that hangs
      net =
        OCPN.new("deadlocked_process", ["Order"])
        |> OCPN.add_place("p_start", "Order", initial: true)
        |> OCPN.add_place("p_a", "Order")
        |> OCPN.add_place("p_b", "Order")
        |> OCPN.add_place("p_end", "Order", terminal: true)
        |> OCPN.add_transition("t_split", "Parallel Split", ["Order"])
        |> OCPN.add_transition("t_bad_join", "Exclusive Join Waiting Both", ["Order"])
        |> OCPN.add_arc("p_start", "t_split", "Order")
        |> OCPN.add_arc("t_split", "p_a", "Order")
        # split puts token in p_a only, but bad_join requires both p_a and p_b
        |> OCPN.add_arc("p_a", "t_bad_join", "Order")
        |> OCPN.add_arc("p_b", "t_bad_join", "Order")
        |> OCPN.add_arc("t_bad_join", "p_end", "Order")

      assert {:error, violation} = SoundnessEngine.verify_reachability(net, "Order")
      assert violation.violation == :deadlock
      assert violation.counter_example_trace == ["t_split"]
      assert "p_a" in violation.deadlocked_marking
    end

    test "detects dead transitions that can never be fired from initial marking" do
      net =
        OCPN.new("dead_transition_process", ["Order"])
        |> OCPN.add_place("p_start", "Order", initial: true)
        |> OCPN.add_place("p_orphan", "Order")
        |> OCPN.add_place("p_end", "Order", terminal: true)
        |> OCPN.add_transition("t_valid", "Valid Path", ["Order"])
        |> OCPN.add_transition("t_dead", "Dead Transition", ["Order"])
        |> OCPN.add_arc("p_start", "t_valid", "Order")
        |> OCPN.add_arc("t_valid", "p_end", "Order")
        |> OCPN.add_arc("p_orphan", "t_dead", "Order")
        |> OCPN.add_arc("t_dead", "p_end", "Order")

      assert {:error, violation} = SoundnessEngine.verify_reachability(net, "Order")
      assert violation.violation == :dead_transitions
      assert "t_dead" in violation.dead_transitions
    end
  end
end
