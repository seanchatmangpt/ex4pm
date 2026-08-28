defmodule Ex4pmCore.WS5.ReleaseEngineTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "ex4pm_engine remains a permanent release application" do
    assert @manifest =~ "ex4pm_engine: :permanent"
  end
end
