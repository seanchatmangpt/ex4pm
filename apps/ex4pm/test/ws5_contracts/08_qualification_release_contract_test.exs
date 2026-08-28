defmodule Ex4pm.WS5.QualificationReleaseContractTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "release keeps ex4pm_qualification permanent" do
    assert @mix =~ "ex4pm_qualification: :permanent"
  end
end
