defmodule Ex4pm.WS5.VerifyTestEnvContractTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "verify command remains admitted in the test environment" do
    assert @mix =~ "verify: :test"
  end
end
