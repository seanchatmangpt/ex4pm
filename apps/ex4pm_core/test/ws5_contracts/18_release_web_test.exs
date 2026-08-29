defmodule Ex4pmCore.WS5.ReleaseWebTest do
  use ExUnit.Case, async: true

  test "release keeps web application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_web: :permanent"
  end
end
