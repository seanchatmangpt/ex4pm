defmodule Ex4pm.WS5.VerifyCompileGateTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../../../mix.exs", __DIR__) |> File.read!()
  test "verify alias preserves warnings-as-errors compilation" do
    assert @mix =~ ~s("compile --warnings-as-errors")
  end
end
