defmodule Ex4pmCore.CapsuleCalibrationModelTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Calibration.{Model, Trial}

  test "fits one exact source and refuses duplicate trials" do
    t0 = DateTime.from_unix!(1_700_000_000)
    {:ok, a} = Trial.new("source", :pass, :pass, t0)
    {:ok, b} = Trial.new("source", :fail, :fail, DateTime.add(t0, 1, :second))
    assert {:ok, model} = Model.fit([a, b])
    assert model.support == 2
    assert model.tp == 1 and model.tn == 1
    assert {:error, {:refused, :duplicate_calibration_trial}} = Model.fit([a, a])
  end
end
