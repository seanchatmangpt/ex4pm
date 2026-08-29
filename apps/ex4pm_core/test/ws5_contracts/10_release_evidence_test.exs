defmodule Ex4pmCore.WS5.ReleaseEvidenceTest do
  use ExUnit.Case, async: true

  test "release keeps the evidence/BRCE application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_evidence: :permanent"
  end
end
