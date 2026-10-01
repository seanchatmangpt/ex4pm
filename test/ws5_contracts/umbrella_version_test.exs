defmodule Ex4pmCore.WS5.UmbrellaVersionTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "umbrella version remains 26.8.22" do
    assert @manifest =~ ~s(version: "26.8.22")
  end
end
