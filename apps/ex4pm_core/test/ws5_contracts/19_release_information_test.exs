defmodule Ex4pmCore.WS5.ReleaseInformationTest do
  use ExUnit.Case, async: true
  test "release keeps information application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_information: :permanent"
  end
end
