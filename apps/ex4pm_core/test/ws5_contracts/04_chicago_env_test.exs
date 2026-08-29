defmodule Ex4pmCore.WS5.ChicagoEnvTest do
  use ExUnit.Case, async: true

  test "Chicago verifier remains bound to MIX_ENV=test" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "chicago: :test"
  end
end
