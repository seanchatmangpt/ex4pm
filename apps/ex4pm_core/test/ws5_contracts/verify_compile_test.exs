defmodule Ex4pmCore.WS5.VerifyCompileTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "verify keeps compile --warnings-as-errors as a required gate" do
    assert @manifest =~ ~s("compile --warnings-as-errors")
  end
end
