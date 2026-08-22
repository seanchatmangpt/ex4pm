defmodule Ex4pmCore.CapsuleCalibrationSubjectTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Calibration.Subject

  test "admits only owner/repo plus exact 40-hex sha" do
    sha = String.duplicate("a", 40)
    assert {:ok, subject} = Subject.new("seanchatmangpt/ex4pm", sha)
    assert Subject.id(subject) == "seanchatmangpt/ex4pm@" <> sha
    assert {:error, {:refused, :inexact_subject}} = Subject.new("ex4pm", sha)
    assert {:error, {:refused, :inexact_subject}} = Subject.new("seanchatmangpt/ex4pm", "main")
  end
end
