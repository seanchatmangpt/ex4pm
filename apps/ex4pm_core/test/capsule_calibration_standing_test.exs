defmodule Ex4pmCore.CapsuleCalibrationStandingTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Calibration.Standing

  test "positive evidence is capped and explicit failure dominates" do
    assert Standing.derive(:accept_bounded, [:pass, :pass], 2, 2) == :partial_alive
    assert Standing.derive(:accept_bounded, [:pass, :pass], 1, 2) == :unknown
    assert Standing.derive(:accept_bounded, [:pass, :fail], 2, 2) == :build_broken
    refute Standing.derive(:accept_bounded, [:pass, :pass], 2, 2) == :alive
  end
end
