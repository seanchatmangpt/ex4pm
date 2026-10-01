defmodule Ex4pmCore.WS5.StreamDataDepTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "stream_data remains the umbrella property-testing dependency" do
    assert @manifest =~ ~s({:stream_data, "~> 1.0"})
  end
end
