defmodule Ex4pmCore.WS5.VerifyEnvTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "verify command remains bound to the test environment" do
    assert @manifest =~ "verify: :test"
  end
end
