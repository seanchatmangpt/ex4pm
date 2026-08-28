defmodule Ex4pmCore.WS5.VerifyTestStageTest do
  use ExUnit.Case, async: true
  test "verify keeps the application test stage" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ ~s("test",\n        "ex4pm.powl.court")
  end
end
