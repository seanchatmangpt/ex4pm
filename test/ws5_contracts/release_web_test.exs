defmodule Ex4pmCore.WS5.ReleaseWebTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "ex4pm_web remains a permanent release application" do
    assert @manifest =~ "ex4pm_web: :permanent"
  end
end
