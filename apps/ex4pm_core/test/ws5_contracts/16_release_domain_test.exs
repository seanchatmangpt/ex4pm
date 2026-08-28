defmodule Ex4pmCore.WS5.ReleaseDomainTest do
  use ExUnit.Case, async: true
  test "release keeps domain application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_domain: :permanent"
  end
end
