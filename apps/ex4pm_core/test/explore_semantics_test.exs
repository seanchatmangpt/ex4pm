defmodule Ex4pm.Explore.SemanticsTest do
  use ExUnit.Case, async: true

  test "fixed point converges monotonically" do
    assert {:ok, 3} = Ex4pm.Explore.FixedPoint.converge(0, &min(&1 + 1, 3), 10)
  end

  test "bounded temporal monitor distinguishes always and eventually" do
    events = [0, 0, 1, 0]
    assert Ex4pm.Explore.TemporalMonitor.eventually?(events, &(&1 == 1), 4)
    refute Ex4pm.Explore.TemporalMonitor.always?(events, &(&1 == 0), 4)
    assert Ex4pm.Explore.TemporalMonitor.until?(events, &(&1 == 0), &(&1 == 1), 4)
  end
end
