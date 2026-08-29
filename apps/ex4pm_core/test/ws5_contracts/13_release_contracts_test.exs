defmodule Ex4pmCore.WS5.ReleaseContractsTest do
  use ExUnit.Case, async: true
  test "release keeps contracts application permanent" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "ex4pm_contracts: :permanent"
  end
end
