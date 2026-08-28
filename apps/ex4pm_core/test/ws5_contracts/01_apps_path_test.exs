defmodule Ex4pmCore.WS5.AppsPathTest do
  use ExUnit.Case, async: true

  test "umbrella apps_path remains apps" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "apps_path: \"apps\""
  end
end
