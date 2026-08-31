defmodule Ex4pm.WS5.CalverContractTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "umbrella release identity remains on the admitted CalVer" do
    assert @mix =~ ~s(version: "26.8.28")
  end
end
