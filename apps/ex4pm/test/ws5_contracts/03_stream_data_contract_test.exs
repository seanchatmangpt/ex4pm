defmodule Ex4pm.WS5.StreamDataContractTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "property-learning surface retains stream_data" do
    assert @mix =~ ~s({:stream_data, "~> 1.0"})
  end
end
