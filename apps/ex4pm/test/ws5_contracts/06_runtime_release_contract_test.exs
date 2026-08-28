defmodule Ex4pm.WS5.RuntimeReleaseContractTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "release keeps ex4pm_runtime permanent" do
    assert @mix =~ "ex4pm_runtime: :permanent"
  end
end
