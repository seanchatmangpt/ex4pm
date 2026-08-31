defmodule Ex4pmCore.WS5.ReleaseRuntimeTest do
  use ExUnit.Case, async: true

  test "release keeps runtime application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_runtime: :permanent"
  end
end
