defmodule Ex4pmCore.WS5.ReleaseStreamTest do
  use ExUnit.Case, async: true
  test "release keeps stream application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_stream: :permanent"
  end
end
