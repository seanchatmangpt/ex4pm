defmodule Ex4pmCore.ExtractorEvidenceObservationTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Observation

  test "admits bounded standing and refuses invented standing" do
    assert {:ok, observation} = Observation.new(:ash, :actions, "abc", :partial_alive)
    assert observation.standing == :partial_alive

    assert {:error, {:refused, :invalid_standing, :crown}} =
             Observation.new(:ash, :actions, "abc", :crown)
  end
end
