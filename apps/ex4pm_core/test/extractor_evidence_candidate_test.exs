defmodule Ex4pmCore.ExtractorEvidenceCandidateTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Candidate

  test "repository extractor modules are observable candidates" do
    assert {:ok, ash} = Candidate.observe(:ash)
    assert ash.name == :ash
    assert ash.module == Ex4pmCore.ProcessIR.Extractor.Ash
    assert ash.standing == :partial_alive
  end
end
