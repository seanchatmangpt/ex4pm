defmodule Ex4pm.WS5.PowlCourtGateTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "verify alias preserves the POWL court" do
    assert @mix =~ ~s("ex4pm.powl.court")
  end
end
