defmodule Ex4pmCore.WS5.ReleaseEngineTest do
  use ExUnit.Case, async: true

  test "release keeps engine application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_engine: :permanent"
  end
end
