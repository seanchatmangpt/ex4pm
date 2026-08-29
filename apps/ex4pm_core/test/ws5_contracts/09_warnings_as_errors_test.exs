defmodule Ex4pmCore.WS5.WarningsAsErrorsTest do
  use ExUnit.Case, async: true

  test "verify keeps compile warnings fatal" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ "compile --warnings-as-errors"
  end
end
