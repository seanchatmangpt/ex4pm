defmodule Ex4pmCore.WS5.StreamDataTest do
  use ExUnit.Case, async: true

  test "stream_data remains available for property falsifiers" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ ~s({:stream_data, "~> 1.0"})
  end
end
