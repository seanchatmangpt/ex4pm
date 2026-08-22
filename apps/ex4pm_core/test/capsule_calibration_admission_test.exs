defmodule Ex4pmCore.CapsuleCalibrationAdmissionTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Calibration.{Admission, Model, Trial, Witness}

  test "future and under-supported evidence fail closed" do
    now = DateTime.from_unix!(1_700_000_010)
    trials = for i <- 0..3 do
      {:ok, trial} = Trial.new("source", :pass, :pass, DateTime.add(now, -10 - i, :second))
      trial
    end
    {:ok, model} = Model.fit(trials)
    {:ok, current} = Witness.new("attempt", "source", :pass, now, "repo")
    assert :ok = Admission.admit(model, current, now, 4)
    assert {:error, {:refused, :insufficient_calibration_support}} = Admission.admit(model, current, now, 5)
    {:ok, future} = Witness.new("attempt", "source", :pass, DateTime.add(now, 1, :second), "repo")
    assert {:error, {:refused, :future_evidence}} = Admission.admit(model, future, now, 4)
  end
end
