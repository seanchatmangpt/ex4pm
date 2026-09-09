defmodule Ex4pmDomain.SparkVerifierTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.SoundnessProver

  test "VerifySoundness admits sound workflow net resource" do
    sound_net = %{
      places: ["p_in", "p_mid", "p_out"],
      transitions: %{
        t1: %{inputs: ["p_in"], outputs: ["p_mid"], label: "step1"},
        t2: %{inputs: ["p_mid"], outputs: ["p_out"], label: "step2"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    report = SoundnessProver.verify_soundness(sound_net)
    assert report.sound? == true
  end

  test "VerifySoundness catches deadlock and unreachable terminal in unsound resource" do
    unsound_net = %{
      places: ["p_in", "p_dead", "p_out"],
      transitions: %{
        t1: %{inputs: ["p_in"], outputs: ["p_dead"], label: "deadlock_step"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    report = SoundnessProver.verify_soundness(unsound_net)
    assert report.sound? == false
    assert report.option_to_complete? == false
    assert report.counterexamples != []
  end
end
