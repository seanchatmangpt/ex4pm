defmodule Ex4pm.WS5.UmbrellaAppsPathTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "umbrella keeps applications rooted under apps" do
    assert @mix =~ ~s(apps_path: "apps")
  end
end
