defmodule Ex4pm.WS5.EvidenceReleaseContractTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "release keeps ex4pm_evidence permanent" do
    assert @mix =~ "ex4pm_evidence: :permanent"
  end
end
