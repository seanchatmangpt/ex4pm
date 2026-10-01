defmodule Ex4pmCore.WS5.ChicagoEnvTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "chicago command remains bound to the test environment" do
    assert @manifest =~ "chicago: :test"
  end
end
