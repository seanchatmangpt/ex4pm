defmodule Ex4pmCore.WS5.VerifyEnvTest do
  use ExUnit.Case, async: true

  test "verify command remains bound to MIX_ENV=test" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "verify: :test"
  end
end
