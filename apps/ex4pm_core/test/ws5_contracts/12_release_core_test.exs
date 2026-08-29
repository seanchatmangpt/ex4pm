defmodule Ex4pmCore.WS5.ReleaseCoreTest do
  use ExUnit.Case, async: true
  test "release keeps canonical core application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_core: :permanent"
  end
end
