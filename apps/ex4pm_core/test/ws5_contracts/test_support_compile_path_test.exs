defmodule Ex4pmCore.WS5.TestSupportCompilePathTest do
  use ExUnit.Case, async: true

  test "test environment compiles core support modules" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ~s|defp elixirc_paths(:test), do: ["lib", "test/support"]|
  end
end
