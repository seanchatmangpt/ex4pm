defmodule Ex4pmCore.CapsuleCalibrationInformationTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Calibration.{Contribution, Decision, Model, Trial}

  test "pass and fail evidence point in opposite directions while unknown is zero" do
    now = DateTime.from_unix!(1_700_000_000)

    trials =
      [
        Trial.new("source", :pass, :pass, now),
        Trial.new("source", :pass, :pass, DateTime.add(now, 1, :second)),
        Trial.new("source", :fail, :fail, DateTime.add(now, 2, :second)),
        Trial.new("source", :fail, :fail, DateTime.add(now, 3, :second))
      ]
      |> Enum.map(fn {:ok, t} -> t end)

    {:ok, model} = Model.fit(trials)
    {:ok, pass} = Contribution.from(model, :pass)
    {:ok, fail} = Contribution.from(model, :fail)
    {:ok, unknown} = Contribution.from(model, :unknown)
    assert pass.log_likelihood > 0
    assert fail.log_likelihood < 0
    assert unknown.log_likelihood == 0.0
    assert {:ok, %{result: :accept_bounded}} = Decision.decide([pass.log_likelihood], 0.1, -0.1)
  end
end
