defmodule Ex4pmCore.WS5.ReleaseContractsTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "ex4pm_contracts remains a permanent release application" do
    assert @manifest =~ "ex4pm_contracts: :permanent"
  end
end
