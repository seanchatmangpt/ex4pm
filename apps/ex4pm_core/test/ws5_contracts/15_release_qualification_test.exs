defmodule Ex4pmCore.WS5.ReleaseQualificationTest do
  use ExUnit.Case, async: true

  test "release keeps qualification application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_qualification: :permanent"
  end
end
