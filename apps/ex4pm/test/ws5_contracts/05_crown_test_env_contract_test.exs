defmodule Ex4pm.WS5.CrownTestEnvContractTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "crown command remains admitted in the test environment" do
    assert @mix =~ ~s("ex4pm.crown": :test)
  end
end
