defmodule Ex4pmCore.WS5.CrownEnvTest do
  use ExUnit.Case, async: true

  test "crown verifier remains bound to MIX_ENV=test" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ ~s("ex4pm.crown": :test)
  end
end
