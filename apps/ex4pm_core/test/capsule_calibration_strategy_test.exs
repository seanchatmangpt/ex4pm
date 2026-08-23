defmodule Ex4pmCore.CapsuleCalibrationStrategyTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Calibration.Strategy

  test "three lawful strategies remain distinct and discoverable" do
    assert Strategy.candidates() == [
             :uniform_cluster,
             :calibrated_log_odds,
             :minimax_under_support
           ]

    {:ok, uniform} = Strategy.evaluate(:uniform_cluster, [2.0, 1.0], [8, 2])
    {:ok, log_odds} = Strategy.evaluate(:calibrated_log_odds, [2.0, 1.0], [8, 2])
    {:ok, minimax} = Strategy.evaluate(:minimax_under_support, [2.0, 1.0], [8, 2])
    assert uniform == 1.5
    assert log_odds == 3.0
    assert minimax == 0.25
  end
end
